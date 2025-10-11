class Api::V1::TicketsController < Api::V1::BaseController
  before_action :find_ticket, only: [:show, :update, :destroy, :assign, :add_note]

  def index
    tickets = Ticket.all
    
    # Apply filters
    tickets = apply_filters(tickets, params)
    
    # Apply search
    if params[:search].present?
      search_results = AdvancedSearchService.search(
        params[:search],
        filters: extract_search_filters(params),
        sort: params[:sort],
        page: params[:page],
        per_page: params[:per_page]
      )
      
      render_success(
        search_results[:results].as_json(include_ai_analysis: true),
        :ok,
        {
          pagination: search_results[:pagination],
          facets: search_results[:facets],
          search_time: search_results[:search_time]
        }
      )
      return
    end

    # Regular pagination
    paginated = paginate(tickets, page: params[:page], per_page: params[:per_page])
    
    render_success(
      paginated[:items].as_json(include_ai_analysis: true),
      :ok,
      { pagination: paginated[:pagination] }
    )
  end

  def show
    render_success(@ticket.as_json(include_ai_analysis: true, include_notes: true))
  end

  def create
    ticket_params = permitted_ticket_params
    
    # Auto-assign if requested
    if params[:auto_assign] == 'true'
      ticket_params[:auto_assign] = true
    end

    ticket = Ticket.new(ticket_params)
    
    if ticket.save
      # Trigger AI analysis in background
      AiAnalysisJob.perform_later(ticket.id) if params[:analyze_ai] != 'false'
      
      # Auto-assign if requested
      if ticket_params[:auto_assign]
        AutoAssignmentService.assign_ticket(ticket)
        ticket.reload
      end

      render_success(
        ticket.as_json(include_ai_analysis: true),
        :created,
        { 
          message: 'Ticket created successfully',
          ai_analysis_queued: params[:analyze_ai] != 'false'
        }
      )
    else
      render_error(
        'Failed to create ticket',
        :unprocessable_entity,
        { errors: ticket.errors.full_messages }
      )
    end
  end

  def update
    if @ticket.update(permitted_ticket_params)
      # Broadcast update via WebSocket
      broadcast_ticket_update(@ticket, 'updated')
      
      render_success(
        @ticket.as_json(include_ai_analysis: true),
        :ok,
        { message: 'Ticket updated successfully' }
      )
    else
      render_error(
        'Failed to update ticket',
        :unprocessable_entity,
        { errors: @ticket.errors.full_messages }
      )
    end
  end

  def destroy
    if @ticket.destroy
      render_success({}, :ok, { message: 'Ticket deleted successfully' })
    else
      render_error('Failed to delete ticket', :unprocessable_entity)
    end
  end

  def assign
    agent_id = params[:agent_id]
    agent = Agent.find(agent_id) if agent_id

    unless agent
      render_error('Invalid agent ID', :bad_request)
      return
    end

    if @ticket.update(assigned_agent_id: agent.id, assigned_at: Time.current)
      # Broadcast assignment
      broadcast_ticket_update(@ticket, 'assigned')
      
      render_success(
        @ticket.as_json(include_ai_analysis: true),
        :ok,
        { message: "Ticket assigned to #{agent.name}" }
      )
    else
      render_error('Failed to assign ticket', :unprocessable_entity)
    end
  end

  def add_note
    note_content = params[:content]
    
    if note_content.blank?
      render_error('Note content is required', :bad_request)
      return
    end

    note = {
      content: note_content,
      agent_id: params[:agent_id],
      created_at: Time.current,
      public: params[:public] == 'true'
    }

    @ticket.notes << note
    
    if @ticket.save
      # Broadcast note addition
      broadcast_ticket_update(@ticket, 'note_added')
      
      render_success(
        { note: note },
        :created,
        { message: 'Note added successfully' }
      )
    else
      render_error('Failed to add note', :unprocessable_entity)
    end
  end

  def bulk_update
    ticket_ids = params[:ticket_ids]
    updates = params[:updates] || {}

    if ticket_ids.blank?
      render_error('Ticket IDs are required', :bad_request)
      return
    end

    tickets = Ticket.where(:id.in => ticket_ids)
    updated_count = 0

    tickets.each do |ticket|
      if ticket.update(updates.permit(:status, :priority, :assigned_agent_id))
        updated_count += 1
        broadcast_ticket_update(ticket, 'bulk_updated')
      end
    end

    render_success(
      { updated_count: updated_count, total_count: tickets.count },
      :ok,
      { message: "#{updated_count} tickets updated successfully" }
    )
  end

  def analytics
    date_range = parse_date_range(params[:date_range] || '30d')
    agent_id = params[:agent_id]

    metrics = AnalyticsService.dashboard_metrics(agent_id, date_range)
    
    render_success(metrics, :ok, { date_range: date_range.to_s })
  end

  def similar
    similar_tickets = AdvancedSearchService.similar_tickets(
      params[:id],
      params[:limit]&.to_i || 5
    )

    render_success(
      similar_tickets.as_json(include_ai_analysis: true),
      :ok,
      { count: similar_tickets.count }
    )
  end

  private

  def find_ticket
    @ticket = Ticket.find(params[:id])
  rescue Mongoid::Errors::DocumentNotFound
    render_error('Ticket not found', :not_found)
  end

  def permitted_ticket_params
    params.require(:ticket).permit(
      :title, :description, :customer_email, :customer_name,
      :priority, :status, :category, :assigned_agent_id
    )
  end

  def apply_filters(tickets, params)
    tickets = tickets.where(status: params[:status]) if params[:status].present?
    tickets = tickets.where(priority: params[:priority]) if params[:priority].present?
    tickets = tickets.where(assigned_agent_id: params[:agent_id]) if params[:agent_id].present?
    
    if params[:created_after].present?
      tickets = tickets.where(created_at: { '$gte' => Time.parse(params[:created_after]) })
    end
    
    if params[:created_before].present?
      tickets = tickets.where(created_at: { '$lte' => Time.parse(params[:created_before]) })
    end

    tickets
  end

  def extract_search_filters(params)
    {
      status: params[:status],
      priority: params[:priority],
      agent_id: params[:agent_id],
      category: params[:category],
      has_ai_analysis: params[:has_ai_analysis]
    }.compact
  end

  def broadcast_ticket_update(ticket, action)
    return unless ticket.assigned_agent_id

    ActionCable.server.broadcast(
      "tickets_#{ticket.assigned_agent_id}",
      {
        action: action,
        ticket: ticket.as_json(include_ai_analysis: true),
        timestamp: Time.current.iso8601
      }
    )
  end

  def parse_date_range(range_string)
    case range_string
    when /(\d+)d/
      $1.to_i.days
    when /(\d+)w/
      $1.to_i.weeks
    when /(\d+)m/
      $1.to_i.months
    else
      30.days
    end
  end
end
