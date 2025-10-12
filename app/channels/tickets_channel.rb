class TicketsChannel < ApplicationCable::Channel
  def subscribed
    stream_from "tickets_#{current_agent.id}" if current_agent
    stream_from "tickets_all" if current_agent&.admin?
  end

  def unsubscribed
    # Any cleanup needed when channel is unsubscribed
  end

  def update_status(data)
    ticket = Ticket.find(data['ticket_id'])
    return unless can_access_ticket?(ticket)
    
    ticket.update(status: data['status'])
    broadcast_ticket_update(ticket, 'status_updated')
  end

  def add_note(data)
    ticket = Ticket.find(data['ticket_id'])
    return unless can_access_ticket?(ticket)
    
    ticket.notes << {
      content: data['content'],
      agent_id: current_agent.id,
      created_at: Time.current
    }
    ticket.save
    
    broadcast_ticket_update(ticket, 'note_added')
  end

  private

  def current_agent
    @current_agent ||= Agent.find(connection.current_agent_id) if connection.current_agent_id
  end

  def can_access_ticket?(ticket)
    current_agent&.admin? || ticket.assigned_agent_id == current_agent&.id
  end

  def broadcast_ticket_update(ticket, action)
    ActionCable.server.broadcast(
      "tickets_#{ticket.assigned_agent_id}",
      {
        action: action,
        ticket: ticket.as_json(include: :notes),
        timestamp: Time.current.iso8601
      }
    )
  end
end
