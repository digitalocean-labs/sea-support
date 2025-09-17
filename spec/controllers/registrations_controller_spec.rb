# LEARNING NOTE: Registration Controller Tests
# These tests verify the signup flow works correctly
# Tests both successful registration and validation failures

require 'rails_helper'

RSpec.describe RegistrationsController, type: :controller do
  describe 'GET #new' do
    context 'when not logged in' do
      it 'renders the signup form' do
        get :new
        expect(response).to be_successful
        expect(assigns(:agent)).to be_a_new(Agent)
      end
    end

    context 'when already logged in' do
      let(:agent) { create(:agent) }
      before { session[:agent_id] = agent.id }

      it 'redirects to root with notice' do
        get :new
        expect(response).to redirect_to(root_path)
        expect(flash[:notice]).to include('Already signed in')
      end
    end
  end

  describe 'POST #create' do
    let(:valid_params) do
      {
        agent: {
          name: 'New Agent',
          email: 'new@moodbrew.com',
          password: 'password123',
          password_confirmation: 'password123'
        }
      }
    end

    context 'with valid parameters' do
      it 'creates a new agent' do
        expect {
          post :create, params: valid_params
        }.to change(Agent, :count).by(1)
      end

      it 'signs in the new agent' do
        post :create, params: valid_params

        new_agent = Agent.find_by(email: 'new@moodbrew.com')
        expect(session[:agent_id]).to eq(new_agent.id)
      end

      it 'redirects to dashboard with welcome message' do
        post :create, params: valid_params

        expect(response).to redirect_to(dashboard_path)
        expect(flash[:notice]).to include('Welcome to MoodBrew Support')
      end

      it 'sets default role to agent' do
        post :create, params: valid_params

        new_agent = Agent.find_by(email: 'new@moodbrew.com')
        expect(new_agent.role).to eq('agent')
      end
    end

    context 'with invalid parameters' do
      let(:invalid_params) do
        {
          agent: {
            name: '',
            email: 'invalid-email',
            password: 'short',
            password_confirmation: 'different'
          }
        }
      end

      it 'does not create an agent' do
        expect {
          post :create, params: invalid_params
        }.not_to change(Agent, :count)
      end

      it 'does not sign in' do
        post :create, params: invalid_params
        expect(session[:agent_id]).to be_nil
      end

      it 'renders new template with errors' do
        post :create, params: invalid_params

        expect(response).to have_http_status(:unprocessable_content)
        expect(response).to render_template(:new)
        expect(assigns(:agent).errors).to be_present
      end
    end

    context 'with duplicate email' do
      let(:existing_agent) { create(:agent, email: 'existing@moodbrew.com') }
      let(:duplicate_params) do
        {
          agent: {
            name: 'Another Agent',
            email: existing_agent.email,
            password: 'password123',
            password_confirmation: 'password123'
          }
        }
      end

      before { existing_agent } # Create the existing agent

      it 'does not create an agent' do
        expect {
          post :create, params: duplicate_params
        }.not_to change(Agent, :count)
      end

      it 'shows validation error for email' do
        post :create, params: duplicate_params

        expect(assigns(:agent).errors[:email]).to include('has already been taken')
      end
    end

    context 'with mismatched password confirmation' do
      let(:mismatched_params) do
        {
          agent: {
            name: 'Test Agent',
            email: 'test@moodbrew.com',
            password: 'password123',
            password_confirmation: 'different123'
          }
        }
      end

      it 'does not create an agent' do
        expect {
          post :create, params: mismatched_params
        }.not_to change(Agent, :count)
      end

      it 'shows password confirmation error' do
        post :create, params: mismatched_params

        expect(assigns(:agent).errors[:password_confirmation]).to be_present
      end
    end
  end
end
