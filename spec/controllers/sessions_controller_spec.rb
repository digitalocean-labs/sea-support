# LEARNING NOTE: Controller Tests for Authentication
# These tests verify the login/logout flow works correctly
# Controller tests focus on the HTTP request/response cycle

require 'rails_helper'

RSpec.describe SessionsController, type: :controller do
  let(:agent) { create(:agent, email: 'test@moodbrew.com', password: 'password123', password_confirmation: 'password123') }

  describe 'GET #new' do
    context 'when not logged in' do
      it 'renders the login form' do
        get :new
        expect(response).to be_successful
        expect(assigns(:agent)).to be_a_new(Agent)
      end
    end

    context 'when already logged in' do
      before { session[:agent_id] = agent.id }

      it 'redirects to dashboard with notice' do
        get :new
        expect(response).to redirect_to(dashboard_path)
        expect(flash[:notice]).to include('Already signed in')
      end
    end
  end

  describe 'POST #create' do
    context 'with valid credentials' do
      let(:valid_params) { { agent: { email: 'test@moodbrew.com', password: 'password123' } } }

      it 'signs in the agent and redirects' do
        # Ensure the agent exists and can authenticate
        expect(agent.authenticate('password123')).to be_truthy

        post :create, params: valid_params

        expect(session[:agent_id]).to eq(agent.id)
        expect(response).to redirect_to(dashboard_path)
        expect(flash[:notice]).to include('Welcome back')
      end

      it 'handles email case insensitivity' do
        # Ensure the agent exists
        expect(agent).to be_persisted

        post :create, params: { agent: { email: 'TEST@MOODBREW.COM', password: 'password123' } }

        expect(session[:agent_id]).to eq(agent.id)
        expect(response).to redirect_to(dashboard_path)
      end
    end

    context 'with invalid credentials' do
      let(:invalid_params) { { agent: { email: 'test@moodbrew.com', password: 'wrong' } } }

      it 'does not sign in and shows error' do
        post :create, params: invalid_params

        expect(session[:agent_id]).to be_nil
        expect(response).to have_http_status(:unprocessable_content)
        expect(flash.now[:alert]).to include('Invalid email or password')
      end

      it 'preserves email in form' do
        post :create, params: invalid_params
        expect(assigns(:agent).email).to eq('test@moodbrew.com')
      end
    end

    context 'with nonexistent email' do
      let(:nonexistent_params) { { agent: { email: 'nonexistent@moodbrew.com', password: 'password123' } } }

      it 'does not sign in and shows error' do
        post :create, params: nonexistent_params

        expect(session[:agent_id]).to be_nil
        expect(flash.now[:alert]).to include('Invalid email or password')
      end
    end
  end

  describe 'DELETE #destroy' do
    context 'when logged in' do
      before { session[:agent_id] = agent.id }

      it 'signs out and redirects to login' do
        delete :destroy

        expect(session[:agent_id]).to be_nil
        expect(response).to redirect_to(login_path)
        expect(flash[:notice]).to include('Goodbye')
      end
    end

    context 'when not logged in' do
      it 'redirects to login without error' do
        delete :destroy

        expect(response).to redirect_to(login_path)
        expect(flash[:notice]).to include('Goodbye')
      end
    end
  end
end
