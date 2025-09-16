# LEARNING NOTE: TicketsController Tests
# These tests verify the CRUD operations work correctly
# Tests both successful operations and error conditions

require 'rails_helper'

RSpec.describe TicketsController, type: :controller do
  let(:agent) { create(:agent) }
  let(:admin_agent) { create(:agent, role: 'admin') }
  let(:supervisor_agent) { create(:agent, role: 'supervisor') }
  let(:ticket) { create(:ticket, assigned_agent: agent) }
  
  before { session[:agent_id] = agent.id }
  
  describe 'GET #index' do
    let!(:tickets) { create_list(:ticket, 3, assigned_agent: agent) }
    
    context 'when logged in as agent' do
      it 'shows only assigned tickets' do
        other_ticket = create(:ticket) # Not assigned to current agent
        
        get :index
        
        expect(response).to be_successful
        expect(assigns(:tickets).count).to eq(3)
        expect(assigns(:tickets)).not_to include(other_ticket)
      end
      
      it 'calculates ticket statistics' do
        create(:ticket, status: 'new', assigned_agent: agent)
        create(:ticket, status: 'resolved', assigned_agent: agent)
        create(:ticket, priority: 'urgent', assigned_agent: agent)
        
        get :index
        
        stats = assigns(:stats)
        expect(stats[:total]).to be > 0
        expect(stats[:new]).to be >= 1
        expect(stats[:resolved]).to be >= 1
        expect(stats[:urgent]).to be >= 1
      end
    end
    
    context 'when logged in as admin' do
      before { session[:agent_id] = admin_agent.id }
      
      it 'shows all tickets' do
        other_tickets = create_list(:ticket, 2) # Not assigned to admin
        
        get :index
        
        expect(assigns(:tickets).count).to eq(5) # 3 + 2
      end
    end
    
    context 'with search parameters' do
      let!(:searchable_ticket) { create(:ticket, subject: 'Coffee not brewing', assigned_agent: agent) }
      
      it 'filters by search term' do
        get :index, params: { q: { search: 'Coffee' } }
        
        expect(assigns(:tickets)).to include(searchable_ticket)
      end
      
      it 'filters by status' do
        resolved_ticket = create(:ticket, status: 'resolved', assigned_agent: agent)
        
        get :index, params: { q: { status: 'resolved' } }
        
        expect(assigns(:tickets)).to include(resolved_ticket)
      end
      
      it 'filters by priority' do
        urgent_ticket = create(:ticket, priority: 'urgent', assigned_agent: agent)
        
        get :index, params: { q: { priority: 'urgent' } }
        
        expect(assigns(:tickets)).to include(urgent_ticket)
      end
    end
  end
  
  describe 'GET #show' do
    it 'displays the ticket' do
      get :show, params: { id: ticket.id }
      
      expect(response).to be_successful
      expect(assigns(:ticket)).to eq(ticket)
    end
    
    it 'logs view activity' do
      expect {
        get :show, params: { id: ticket.id }
      }.to change { ticket.reload.activities.count }.by(1)
      
      activity = ticket.activities.find_by(action: 'viewed')
      expect(activity.action).to eq('viewed')
      expect(activity.performed_by).to eq(agent.display_name)
    end
    
    it 'does not duplicate view activities' do
      # First view
      get :show, params: { id: ticket.id }
      
      expect {
        # Second view by same agent
        get :show, params: { id: ticket.id }
      }.not_to change { ticket.reload.activities.count }
    end
    
    context 'with non-existent ticket' do
      it 'redirects with error message' do
        get :show, params: { id: 'nonexistent' }
        
        expect(response).to redirect_to(tickets_path)
        expect(flash[:alert]).to include('not found')
      end
    end
  end
  
  describe 'GET #new' do
    it 'creates a new ticket' do
      get :new
      
      expect(response).to be_successful
      expect(assigns(:ticket)).to be_a_new(Ticket)
      expect(assigns(:ticket).customer_info).to be_present
    end
  end
  
  describe 'POST #create' do
    let(:valid_params) do
      {
        ticket: {
          subject: 'Test ticket',
          description: 'Test description',
          priority: 'medium',
          issue_category: 'brewing',
          machine_model: 'MoodBrew Pro',
          customer_info_attributes: {
            customer_name: 'John Doe',
            email: 'john@example.com',
            phone: '555-0123'
          }
        }
      }
    end
    
    context 'with valid parameters' do
      it 'creates a new ticket' do
        expect {
          post :create, params: valid_params
        }.to change(Ticket, :count).by(1)
      end
      
      it 'assigns to current agent' do
        post :create, params: valid_params
        
        new_ticket = Ticket.last
        expect(new_ticket.assigned_agent).to eq(agent)
        expect(new_ticket.created_by).to eq(agent)
      end
      
      it 'generates unique ticket number' do
        post :create, params: valid_params
        
        new_ticket = Ticket.last
        expect(new_ticket.ticket_number).to be_present
        expect(new_ticket.ticket_number).to match(/TKT-\d{8}-\w{6}/)
      end
      
      it 'creates initial customer message' do
        post :create, params: valid_params
        
        new_ticket = Ticket.last
        expect(new_ticket.messages.count).to eq(1)
        expect(new_ticket.messages.first.sender).to eq('customer')
        expect(new_ticket.messages.first.content).to eq('Test description')
      end
      
      it 'logs creation activity' do
        post :create, params: valid_params
        
        new_ticket = Ticket.last
        creation_activity = new_ticket.activities.find_by(action: 'created')
        expect(creation_activity).to be_present
        expect(creation_activity.performed_by).to eq(agent.display_name)
      end
      
      it 'redirects to ticket with success message' do
        post :create, params: valid_params
        
        new_ticket = Ticket.last
        expect(response).to redirect_to(new_ticket)
        expect(flash[:notice]).to include('created successfully')
      end
    end
    
    context 'with invalid parameters' do
      let(:invalid_params) do
        {
          ticket: {
            subject: '', # Required field
            description: '',
            priority: 'invalid_priority'
          }
        }
      end
      
      it 'does not create a ticket' do
        expect {
          post :create, params: invalid_params
        }.not_to change(Ticket, :count)
      end
      
      it 'renders new template with errors' do
        post :create, params: invalid_params
        
        expect(response).to have_http_status(:unprocessable_content)
        expect(response).to render_template(:new)
        expect(assigns(:ticket).errors).to be_present
      end
    end
  end
  
  describe 'GET #edit' do
    it 'loads the ticket for editing' do
      get :edit, params: { id: ticket.id }
      
      expect(response).to be_successful
      expect(assigns(:ticket)).to eq(ticket)
    end
    
    it 'builds customer info if missing' do
      ticket_without_customer = create(:ticket, assigned_agent: agent)
      ticket_without_customer.customer_info = nil
      ticket_without_customer.save!
      
      get :edit, params: { id: ticket_without_customer.id }
      
      expect(assigns(:ticket).customer_info).to be_present
    end
  end
  
  describe 'PATCH #update' do
    let(:update_params) do
      {
        id: ticket.id,
        ticket: {
          subject: 'Updated subject',
          status: 'in_progress',
          priority: 'high'
        }
      }
    end
    
    context 'with valid parameters' do
      it 'updates the ticket' do
        patch :update, params: update_params
        
        ticket.reload
        expect(ticket.subject).to eq('Updated subject')
        expect(ticket.status).to eq('in_progress')
        expect(ticket.priority).to eq('high')
      end
      
      it 'logs status change activity' do
        original_status = ticket.status
        
        expect {
          patch :update, params: update_params
        }.to change { ticket.reload.activities.count }
        
        status_activity = ticket.activities.find_by(action: 'status_changed')
        expect(status_activity).to be_present
        expect(status_activity.description).to include(original_status)
        expect(status_activity.description).to include('in_progress')
      end
      
      it 'logs priority change activity' do
        patch :update, params: update_params
        
        priority_activity = ticket.reload.activities.find_by(action: 'priority_changed')
        expect(priority_activity).to be_present
        expect(priority_activity.description).to include('high')
      end
      
      it 'redirects with success message' do
        patch :update, params: update_params
        
        expect(response).to redirect_to(ticket)
        expect(flash[:notice]).to include('updated successfully')
      end
    end
    
    context 'with assignment change' do
      let(:new_agent) { create(:agent) }
      let(:assignment_params) do
        {
          id: ticket.id,
          ticket: { assigned_agent_id: new_agent.id }
        }
      end
      
      it 'logs assignment change' do
        patch :update, params: assignment_params
        
        assignment_activity = ticket.reload.activities.find_by(action: 'assigned')
        expect(assignment_activity).to be_present
        expect(assignment_activity.description).to include(new_agent.display_name)
      end
    end
    
    context 'with invalid parameters' do
      let(:invalid_update_params) do
        {
          id: ticket.id,
          ticket: {
            subject: '', # Required field
            priority: 'invalid_priority'
          }
        }
      end
      
      it 'does not update the ticket' do
        original_subject = ticket.subject
        
        patch :update, params: invalid_update_params
        
        expect(ticket.reload.subject).to eq(original_subject)
      end
      
      it 'renders edit template with errors' do
        patch :update, params: invalid_update_params
        
        expect(response).to have_http_status(:unprocessable_content)
        expect(response).to render_template(:edit)
        expect(assigns(:ticket).errors).to be_present
      end
    end
  end
  
  describe 'DELETE #destroy' do
    context 'when logged in as admin' do
      before { session[:agent_id] = admin_agent.id }
      
      it 'deletes the ticket' do
        ticket_to_delete = create(:ticket)
        
        expect {
          delete :destroy, params: { id: ticket_to_delete.id }
        }.to change(Ticket, :count).by(-1)
      end
      
      it 'redirects with success message' do
        delete :destroy, params: { id: ticket.id }
        
        expect(response).to redirect_to(tickets_path)
        expect(flash[:notice]).to include('deleted')
      end
    end
    
    context 'when logged in as regular agent' do
      it 'denies access' do
        delete :destroy, params: { id: ticket.id }
        
        expect(response).to redirect_to(tickets_path)
        expect(flash[:alert]).to include('Only administrators')
      end
      
      it 'does not delete the ticket' do
        ticket_to_test = ticket # Force creation of ticket before counting
        
        expect {
          delete :destroy, params: { id: ticket_to_test.id }
        }.not_to change(Ticket, :count)
      end
    end
  end
  
  describe 'authentication requirements' do
    before { session[:agent_id] = nil } # Simulate not logged in
    
    it 'requires authentication for index' do
      get :index
      expect(response).to redirect_to(login_path)
    end
    
    it 'requires authentication for show' do
      get :show, params: { id: ticket.id }
      expect(response).to redirect_to(login_path)
    end
    
    it 'requires authentication for new' do
      get :new
      expect(response).to redirect_to(login_path)
    end
    
    it 'requires authentication for create' do
      post :create, params: { ticket: { subject: 'Test' } }
      expect(response).to redirect_to(login_path)
    end
  end
end