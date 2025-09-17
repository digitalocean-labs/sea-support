# LEARNING NOTE: RSpec Model Tests
# Model tests verify business logic, validations, and relationships
# They're fast because they don't involve controllers or views

require 'rails_helper'

RSpec.describe Agent, type: :model do
  # LEARNING NOTE: let vs let!
  # let() is lazy - only creates when first used
  # let!() is eager - creates immediately
  let(:agent) { build(:agent) }  # build() creates object without saving

  describe 'validations' do
    # LEARNING NOTE: Testing Validations
    # We test both valid and invalid states
    context 'with valid attributes' do
      it 'is valid' do
        expect(agent).to be_valid
      end
    end

    context 'email validation' do
      it 'requires an email' do
        agent.email = nil
        expect(agent).not_to be_valid
        expect(agent.errors[:email]).to include("can't be blank")
      end

      it 'requires a valid email format' do
        agent.email = 'invalid-email'
        expect(agent).not_to be_valid
        expect(agent.errors[:email]).to include("is invalid")
      end

      it 'requires unique email' do
        # LEARNING NOTE: create() saves to database, build() doesn't
        existing_agent = create(:agent, email: 'test@moodbrew.com')
        agent.email = 'test@moodbrew.com'
        expect(agent).not_to be_valid
        expect(agent.errors[:email]).to include("has already been taken")
      end
    end

    context 'role validation' do
      it 'accepts valid roles' do
        %w[agent supervisor admin].each do |role|
          agent.role = role
          expect(agent).to be_valid
        end
      end

      it 'rejects invalid roles' do
        agent.role = 'invalid_role'
        expect(agent).not_to be_valid
        expect(agent.errors[:role]).to include("is not included in the list")
      end
    end
  end

  describe 'authentication' do
    # LEARNING NOTE: Testing has_secure_password
    it 'authenticates with correct password' do
      agent = create(:agent, password: 'password123')
      expect(agent.authenticate('password123')).to eq(agent)
    end

    it 'does not authenticate with incorrect password' do
      agent = create(:agent, password: 'password123')
      expect(agent.authenticate('wrong_password')).to be_falsey
    end
  end

  describe 'scopes' do
    # LEARNING NOTE: Testing Scopes
    # Create test data first, then verify scope behavior
    let!(:regular_agent) { create(:agent, role: 'agent') }
    let!(:supervisor) { create(:agent, :supervisor) }
    let!(:admin) { create(:agent, :admin) }

    it 'filters agents by role' do
      expect(Agent.agents).to include(regular_agent)
      expect(Agent.agents).not_to include(supervisor, admin)
    end

    it 'filters supervisors by role' do
      expect(Agent.supervisors).to include(supervisor)
      expect(Agent.supervisors).not_to include(regular_agent, admin)
    end
  end

  describe 'methods' do
    describe '#display_name' do
      it 'returns name when present' do
        agent.name = 'John Doe'
        expect(agent.display_name).to eq('John Doe')
      end

      it 'returns titleized email prefix when name is blank' do
        agent.name = ''
        agent.email = 'john.doe@moodbrew.com'
        expect(agent.display_name).to eq('John.Doe')
      end
    end

    describe 'role checking methods' do
      it 'identifies admin correctly' do
        admin = build(:agent, :admin)
        expect(admin).to be_admin
        expect(admin).to be_supervisor  # admin is also supervisor
      end

      it 'identifies supervisor correctly' do
        supervisor = build(:agent, :supervisor)
        expect(supervisor).to be_supervisor
        expect(supervisor).not_to be_admin
      end

      it 'identifies regular agent correctly' do
        regular_agent = build(:agent)
        expect(regular_agent).not_to be_admin
        expect(regular_agent).not_to be_supervisor
      end
    end
  end

  describe 'embedded documents' do
    # LEARNING NOTE: Testing MongoDB Embedded Documents
    let(:agent) { create(:agent) }

    it 'creates preferences after creation' do
      expect(agent.preferences).to be_present
      expect(agent.preferences.theme).to eq('coffee')  # MoodBrew default
    end

    it 'creates performance metrics after creation' do
      expect(agent.performance_metrics).to be_present
      expect(agent.performance_metrics.tickets_resolved).to eq(0)
    end
  end

  describe 'callbacks' do
    it 'normalizes email before saving' do
      agent = build(:agent, email: 'JOHN@MOODBREW.COM')  # Use uppercase to test downcasing
      agent.save!
      expect(agent.reload.email).to eq('john@moodbrew.com')
    end
  end

  # MOODBREW THEME: Fun coffee-themed tests
  describe 'MoodBrew coffee features' do
    let(:coffee_agent) { create(:agent, :coffee_lover) }

    it 'supports coffee theme preferences' do
      expect(coffee_agent.preferences.theme).to eq('coffee')
    end

    it 'tracks coffee breaks' do
      expect(coffee_agent.performance_metrics.coffee_breaks_today).to be >= 0
    end
  end
end
