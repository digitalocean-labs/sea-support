class AutoAssignmentService
  include Mongoid::Document

  # Assignment strategies
  STRATEGIES = {
    round_robin: 'RoundRobinStrategy',
    skill_based: 'SkillBasedStrategy',
    workload_balanced: 'WorkloadBalancedStrategy',
    ai_optimized: 'AiOptimizedStrategy'
  }.freeze

  class << self
    def assign_ticket(ticket, strategy: :ai_optimized)
      return false unless ticket.assigned_agent_id.nil?

      strategy_class = "AutoAssignmentService::#{STRATEGIES[strategy]}".constantize
      agent = strategy_class.new.find_best_agent(ticket)

      if agent
        assign_to_agent(ticket, agent)
        log_assignment(ticket, agent, strategy)
        true
      else
        handle_no_agent_available(ticket)
        false
      end
    end

    def bulk_reassign_tickets(criteria = {})
      tickets = Ticket.where(criteria.merge(assigned_agent_id: nil))
      results = { assigned: 0, failed: 0 }

      tickets.each do |ticket|
        if assign_ticket(ticket)
          results[:assigned] += 1
        else
          results[:failed] += 1
        end
      end

      results
    end

    def rebalance_workload
      overloaded_agents = find_overloaded_agents
      underloaded_agents = find_underloaded_agents

      return if overloaded_agents.empty? || underloaded_agents.empty?

      rebalance_between_agents(overloaded_agents, underloaded_agents)
    end

    private

    def assign_to_agent(ticket, agent)
      ticket.update!(
        assigned_agent_id: agent.id,
        assigned_at: Time.current,
        status: 'assigned'
      )

      # Notify agent via WebSocket
      ActionCable.server.broadcast(
        "tickets_#{agent.id}",
        {
          action: 'ticket_assigned',
          ticket: ticket.as_json,
          timestamp: Time.current.iso8601
        }
      )
    end

    def log_assignment(ticket, agent, strategy)
      Rails.logger.info "[AUTO_ASSIGNMENT] Ticket #{ticket.id} assigned to #{agent.name} via #{strategy}"
      
      # Track assignment metrics
      AssignmentMetric.create!(
        ticket_id: ticket.id,
        agent_id: agent.id,
        strategy: strategy.to_s,
        assigned_at: Time.current
      )
    end

    def handle_no_agent_available(ticket)
      ticket.update!(
        status: 'pending_assignment',
        escalated: true,
        escalated_at: Time.current
      )

      # Notify administrators
      notify_admins_no_agent_available(ticket)
    end

    def find_overloaded_agents
      Agent.active.select do |agent|
        current_workload(agent) > agent.max_concurrent_tickets
      end
    end

    def find_underloaded_agents
      Agent.active.select do |agent|
        current_workload(agent) < (agent.max_concurrent_tickets * 0.7)
      end
    end

    def current_workload(agent)
      Ticket.where(assigned_agent_id: agent.id, status: { '$in' => ['open', 'assigned', 'in_progress'] }).count
    end

    def rebalance_between_agents(overloaded, underloaded)
      overloaded.each do |agent|
        excess_tickets = current_workload(agent) - agent.max_concurrent_tickets
        next if excess_tickets <= 0

        # Find tickets to reassign (prefer newer, lower priority tickets)
        tickets_to_reassign = Ticket.where(
          assigned_agent_id: agent.id,
          status: { '$in' => ['assigned', 'open'] }
        ).order_by(priority: 1, created_at: -1).limit(excess_tickets)

        tickets_to_reassign.each do |ticket|
          new_agent = underloaded.min_by { |a| current_workload(a) }
          next unless new_agent && current_workload(new_agent) < new_agent.max_concurrent_tickets

          reassign_ticket(ticket, agent, new_agent)
        end
      end
    end

    def reassign_ticket(ticket, from_agent, to_agent)
      ticket.update!(
        assigned_agent_id: to_agent.id,
        reassigned_at: Time.current,
        reassignment_reason: 'workload_rebalancing'
      )

      # Notify both agents
      [from_agent, to_agent].each do |agent|
        ActionCable.server.broadcast(
          "tickets_#{agent.id}",
          {
            action: 'ticket_reassigned',
            ticket: ticket.as_json,
            timestamp: Time.current.iso8601
          }
        )
      end
    end

    def notify_admins_no_agent_available(ticket)
      admin_agents = Agent.where(role: 'admin')
      admin_agents.each do |admin|
        ActionCable.server.broadcast(
          "tickets_#{admin.id}",
          {
            action: 'no_agent_available',
            ticket: ticket.as_json,
            timestamp: Time.current.iso8601
          }
        )
      end
    end
  end

  # Assignment Strategies
  class RoundRobinStrategy
    def find_best_agent(ticket)
      Agent.active.order_by(last_assigned_at: 1).first
    end
  end

  class SkillBasedStrategy
    def find_best_agent(ticket)
      required_skills = extract_required_skills(ticket)
      
      Agent.active.select do |agent|
        agent.skills && (required_skills - agent.skills).empty?
      end.min_by { |agent| current_workload(agent) }
    end

    private

    def extract_required_skills(ticket)
      category = ticket.ai_analysis&.dig('category')
      
      case category
      when 'technical'
        ['technical_support', 'troubleshooting']
      when 'billing'
        ['billing', 'payments']
      when 'general'
        ['customer_service']
      else
        ['general_support']
      end
    end

    def current_workload(agent)
      Ticket.where(assigned_agent_id: agent.id, status: { '$in' => ['open', 'assigned', 'in_progress'] }).count
    end
  end

  class WorkloadBalancedStrategy
    def find_best_agent(ticket)
      Agent.active.min_by { |agent| workload_score(agent) }
    end

    private

    def workload_score(agent)
      current_tickets = current_workload(agent)
      max_tickets = agent.max_concurrent_tickets || 10
      
      # Calculate score based on current load and agent performance
      base_score = (current_tickets.to_f / max_tickets) * 100
      performance_modifier = (100 - agent.performance_score) * 0.1
      
      base_score + performance_modifier
    end

    def current_workload(agent)
      Ticket.where(assigned_agent_id: agent.id, status: { '$in' => ['open', 'assigned', 'in_progress'] }).count
    end
  end

  class AiOptimizedStrategy
    def find_best_agent(ticket)
      agents = Agent.active.to_a
      return agents.first if agents.size == 1

      # Use AI analysis to predict best agent match
      agent_scores = agents.map do |agent|
        {
          agent: agent,
          score: calculate_match_score(ticket, agent)
        }
      end

      best_match = agent_scores.max_by { |item| item[:score] }
      best_match[:agent]
    end

    private

    def calculate_match_score(ticket, agent)
      score = 0

      # Skill matching
      if ticket.ai_analysis&.dig('category')
        category_skills = get_category_skills(ticket.ai_analysis['category'])
        skill_match = (agent.skills & category_skills).size.to_f / category_skills.size
        score += skill_match * 40
      end

      # Workload consideration
      current_load = current_workload(agent)
      max_load = agent.max_concurrent_tickets || 10
      load_factor = 1 - (current_load.to_f / max_load)
      score += load_factor * 30

      # Performance history
      score += (agent.performance_score || 50) * 0.2

      # Priority matching (high priority tickets to experienced agents)
      if ticket.priority == 'high' && agent.experience_level == 'senior'
        score += 10
      end

      score
    end

    def get_category_skills(category)
      {
        'technical' => ['technical_support', 'troubleshooting', 'hardware'],
        'billing' => ['billing', 'payments', 'subscriptions'],
        'general' => ['customer_service', 'communication'],
        'product' => ['product_knowledge', 'features']
      }[category] || ['general_support']
    end

    def current_workload(agent)
      Ticket.where(assigned_agent_id: agent.id, status: { '$in' => ['open', 'assigned', 'in_progress'] }).count
    end
  end
end

# Model for tracking assignment metrics
class AssignmentMetric
  include Mongoid::Document
  include Mongoid::Timestamps

  field :ticket_id, type: String
  field :agent_id, type: String
  field :strategy, type: String
  field :assigned_at, type: Time
  field :resolution_time, type: Integer # seconds
  field :customer_satisfaction, type: Float

  index({ ticket_id: 1 })
  index({ agent_id: 1, assigned_at: -1 })
  index({ strategy: 1, assigned_at: -1 })
end
