# spec/models/ticket_spec.rb
# LEARNING NOTE: RSpec Testing for MongoDB Models
# Tests validations, callbacks, scopes, and business logic

require 'rails_helper'

RSpec.describe Ticket, type: :model do
  # LEARNING NOTE: let creates lazy-loaded test data
  # It's only created when first referenced in a test
  let(:ticket) { build(:ticket) }
  let(:agent) { create(:agent) }
  
  describe 'validations' do
    it 'is valid with valid attributes' do
      expect(ticket).to be_valid
    end
    
    it 'requires a subject' do
      ticket.subject = nil
      expect(ticket).not_to be_valid
      expect(ticket.errors[:subject]).to include("can't be blank")
    end
    
    it 'requires subject to be between 5 and 200 characters' do
      ticket.subject = 'Bad'
      expect(ticket).not_to be_valid
      expect(ticket.errors[:subject]).to include('is too short (minimum is 5 characters)')
      
      ticket.subject = 'A' * 201
      expect(ticket).not_to be_valid
      expect(ticket.errors[:subject]).to include('is too long (maximum is 200 characters)')
    end
    
    it 'requires a description' do
      ticket.description = nil
      expect(ticket).not_to be_valid
      expect(ticket.errors[:description]).to include("can't be blank")
    end
    
    it 'requires description to be at least 10 characters' do
      ticket.description = 'Too short'
      expect(ticket).not_to be_valid
      expect(ticket.errors[:description]).to include('is too short (minimum is 10 characters)')
    end
    
    it 'validates status inclusion' do
      invalid_statuses = ['pending', 'archived', 'deleted']
      invalid_statuses.each do |status|
        ticket.status = status
        expect(ticket).not_to be_valid
        expect(ticket.errors[:status]).to include('is not included in the list')
      end
    end
    
    it 'validates priority inclusion' do
      ticket.priority = 'critical'
      expect(ticket).not_to be_valid
      expect(ticket.errors[:priority]).to include('is not included in the list')
    end
    
    it 'validates machine_model if provided' do
      ticket.machine_model = 'MoodBrew Super'
      expect(ticket).not_to be_valid
      expect(ticket.errors[:machine_model]).to include('is not included in the list')
      
      ticket.machine_model = 'MoodBrew Pro'
      expect(ticket).to be_valid
    end
  end
  
  describe 'callbacks' do
    describe '#generate_ticket_number' do
      it 'generates a unique ticket number on create' do
        expect(ticket.ticket_number).to be_nil
        ticket.save!
        expect(ticket.ticket_number).to match(/^TKT-\d{8}-[A-F0-9]{6}$/)
      end
      
      it 'does not regenerate ticket number on update' do
        ticket.save!
        original_number = ticket.ticket_number
        ticket.update!(subject: 'Updated subject')
        expect(ticket.ticket_number).to eq(original_number)
      end
    end
    
    describe '#create_initial_activity' do
      it 'creates an activity log on ticket creation' do
        expect { ticket.save! }.to change { ticket.activities.count }.by(1)
        
        activity = ticket.activities.first
        expect(activity.action).to eq('created')
        expect(activity.description).to eq('Ticket created')
      end
    end
    
    describe '#log_status_change' do
      it 'logs activity when status changes' do
        ticket.save!
        expect {
          ticket.update!(status: 'in_progress')
        }.to change { ticket.activities.count }.by(1)
        
        activity = ticket.activities.last
        expect(activity.action).to eq('status_changed')
        expect(activity.description).to include('from new to in_progress')
      end
    end
  end
  
  describe 'scopes' do
    # LEARNING NOTE: let! creates data immediately (not lazy)
    let!(:new_ticket) { create(:ticket, status: 'new') }
    let!(:open_ticket) { create(:ticket, status: 'open') }
    let!(:resolved_ticket) { create(:ticket, status: 'resolved') }
    let!(:high_priority) { create(:ticket, :high_priority) }
    let!(:low_priority) { create(:ticket, priority: 'low') }
    
    describe '.open_tickets' do
      it 'returns tickets with new, open, or in_progress status' do
        in_progress = create(:ticket, status: 'in_progress')
        
        results = Ticket.open_tickets
        expect(results).to include(new_ticket, open_ticket, in_progress)
        expect(results).not_to include(resolved_ticket)
      end
    end
    
    describe '.closed_tickets' do
      it 'returns resolved and closed tickets' do
        closed = create(:ticket, status: 'closed')
        
        results = Ticket.closed_tickets
        expect(results).to include(resolved_ticket, closed)
        expect(results).not_to include(new_ticket, open_ticket)
      end
    end
    
    describe '.high_priority' do
      it 'returns high and urgent priority tickets' do
        urgent = create(:ticket, priority: 'urgent')
        
        results = Ticket.high_priority
        expect(results).to include(high_priority, urgent)
        expect(results).not_to include(low_priority)
      end
    end
    
    describe '.unassigned' do
      it 'returns tickets without an assigned agent' do
        assigned = create(:ticket, :assigned)
        
        results = Ticket.unassigned
        expect(results).to include(new_ticket, open_ticket)
        expect(results).not_to include(assigned)
      end
    end
  end
  
  describe 'embedded documents' do
    describe 'CustomerInfo' do
      let(:ticket_with_customer) { build(:ticket, :with_customer) }
      
      it 'embeds customer information' do
        expect(ticket_with_customer.customer_info).to be_present
        expect(ticket_with_customer.customer_info.email).to match(URI::MailTo::EMAIL_REGEXP)
      end
      
      it 'validates customer email format' do
        ticket_with_customer.customer_info.email = 'invalid-email'
        expect(ticket_with_customer).not_to be_valid
      end
    end
    
    describe 'AiAnalysis' do
      let(:ticket_with_ai) { create(:ticket, :with_ai_analysis) }
      
      it 'embeds AI analysis data' do
        expect(ticket_with_ai.ai_analysis).to be_present
        expect(ticket_with_ai.ai_analysis.tags).to be_an(Array)
        expect(ticket_with_ai.ai_analysis.confidence_score).to be_between(0.5, 1.0)
      end
      
      it 'checks if analysis is stale' do
        fresh_analysis = ticket_with_ai.ai_analysis
        expect(fresh_analysis.stale?).to be false
        
        fresh_analysis.processed_at = 2.hours.ago
        expect(fresh_analysis.stale?).to be true
      end
      
      it 'identifies high confidence predictions' do
        ticket_with_ai.ai_analysis.confidence_score = 0.9
        expect(ticket_with_ai.ai_analysis.high_confidence?).to be true
        
        ticket_with_ai.ai_analysis.confidence_score = 0.7
        expect(ticket_with_ai.ai_analysis.high_confidence?).to be false
      end
    end
    
    describe 'Messages' do
      let(:ticket_with_messages) { create(:ticket, :with_messages) }
      
      it 'embeds multiple messages' do
        expect(ticket_with_messages.messages.count).to eq(2)
        expect(ticket_with_messages.messages.first.sender).to eq('customer')
        expect(ticket_with_messages.messages.last.sender).to eq('agent')
      end
      
      it 'identifies message sender type' do
        customer_msg = ticket_with_messages.messages.first
        expect(customer_msg.from_customer?).to be true
        expect(customer_msg.from_agent?).to be false
      end
    end
  end
  
  describe 'business logic methods' do
    describe '#assign_to' do
      it 'assigns ticket to an agent' do
        ticket.save!
        expect(ticket.assign_to(agent)).to be true
        expect(ticket.assigned_agent).to eq(agent)
      end
      
      it 'logs assignment activity' do
        ticket.save!
        expect { ticket.assign_to(agent) }.to change { ticket.activities.count }.by(1)
        
        activity = ticket.activities.last
        expect(activity.action).to eq('assigned')
        expect(activity.description).to include(agent.display_name)
      end
      
      it 'returns false for invalid agent' do
        ticket.save!
        expect(ticket.assign_to('not an agent')).to be false
      end
    end
    
    describe '#resolve!' do
      it 'changes status to resolved' do
        ticket.save!
        ticket.resolve!('Issue fixed')
        expect(ticket.status).to eq('resolved')
      end
      
      it 'logs resolution activity' do
        ticket.save!
        # resolve! creates 2 activities: one for resolution + one for status change
        expect { ticket.resolve!('Fixed by resetting') }.to change { ticket.activities.count }.by(2)
        
        # Check that the resolution activity was created
        resolution_activity = ticket.activities.where(action: 'resolved').first
        expect(resolution_activity.description).to eq('Fixed by resetting')
      end
    end
    
    describe '#reopen!' do
      it 'changes status back to open' do
        resolved_ticket = create(:ticket, :resolved)
        resolved_ticket.reopen!('Customer reports issue persists')
        expect(resolved_ticket.status).to eq('open')
      end
    end
    
    describe '#add_message' do
      it 'adds a new message to the ticket' do
        ticket.save!
        expect {
          ticket.add_message('customer', 'Still having issues')
        }.to change { ticket.messages.count }.by(1)
        
        message = ticket.messages.last
        expect(message.content).to eq('Still having issues')
      end
    end
    
    describe '#age_in_hours' do
      it 'calculates ticket age in hours' do
        ticket.save!
        ticket.created_at = 3.hours.ago
        expect(ticket.age_in_hours).to eq(3)
      end
    end
    
    describe '#escalated?' do
      it 'identifies escalated tickets' do
        urgent = create(:ticket, priority: 'urgent')
        expect(urgent.escalated?).to be true
        
        old_high_priority = create(:ticket, priority: 'high', created_at: 25.hours.ago)
        expect(old_high_priority.escalated?).to be true
        
        new_medium = create(:ticket, priority: 'medium')
        expect(new_medium.escalated?).to be false
      end
    end
    
    describe '#sla_breach?' do
      it 'detects SLA breaches based on priority' do
        # Urgent: 4 hour SLA
        urgent = create(:ticket, priority: 'urgent', created_at: 5.hours.ago)
        expect(urgent.sla_breach?).to be true
        
        # High: 24 hour SLA
        high = create(:ticket, priority: 'high', created_at: 25.hours.ago)
        expect(high.sla_breach?).to be true
        
        # Medium: 72 hour SLA
        medium = create(:ticket, priority: 'medium', created_at: 73.hours.ago)
        expect(medium.sla_breach?).to be true
        
        # Low: no SLA
        low = create(:ticket, priority: 'low', created_at: 100.hours.ago)
        expect(low.sla_breach?).to be false
      end
    end
  end
  
  describe 'AI integration' do
    describe '#needs_ai_analysis?' do
      it 'returns true when no AI analysis exists' do
        expect(ticket.needs_ai_analysis?).to be true
      end
      
      it 'returns true when analysis is stale' do
        ticket_with_old_ai = create(:ticket, :with_ai_analysis)
        ticket_with_old_ai.ai_analysis.processed_at = 2.hours.ago
        expect(ticket_with_old_ai.needs_ai_analysis?).to be true
      end
      
      it 'returns false when analysis is fresh' do
        ticket_with_ai = create(:ticket, :with_ai_analysis)
        expect(ticket_with_ai.needs_ai_analysis?).to be false
      end
    end
    
    describe '#apply_ai_suggestions' do
      it 'creates AI analysis from suggestions' do
        ticket.save!
        suggestions = {
          tags: ['urgent', 'hardware'],
          priority_suggestion: 'high',
          confidence_score: 0.9
        }
        
        expect(ticket.apply_ai_suggestions(suggestions)).to be_truthy
        expect(ticket.ai_analysis).to be_present
        expect(ticket.ai_analysis.tags).to eq(['urgent', 'hardware'])
      end
      
      it 'auto-applies high confidence suggestions' do
        ticket.save!
        suggestions = {
          priority_suggestion: 'urgent',
          confidence_score: 0.95
        }
        
        ticket.apply_ai_suggestions(suggestions)
        expect(ticket.priority).to eq('urgent')
      end
      
      it 'does not auto-apply low confidence suggestions' do
        ticket.save!
        original_priority = ticket.priority
        suggestions = {
          priority_suggestion: 'urgent',
          confidence_score: 0.6
        }
        
        ticket.apply_ai_suggestions(suggestions)
        expect(ticket.priority).to eq(original_priority)
      end
    end
  end
  
  # LEARNING NOTE: Database cleanup for MongoDB
  # This ensures each test has a clean slate
  after(:each) do
    Ticket.destroy_all
    Agent.destroy_all
  end
end