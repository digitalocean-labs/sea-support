class AnalyticsService
  include Mongoid::Document

  # Cache analytics data for performance
  CACHE_TTL = 1.hour

  class << self
    def dashboard_metrics(agent_id = nil, date_range = 30.days)
      cache_key = "analytics:dashboard:#{agent_id}:#{date_range.to_i}"
      
      Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
        {
          ticket_metrics: ticket_metrics(agent_id, date_range),
          ai_performance: ai_performance_metrics(date_range),
          agent_performance: agent_performance_metrics(agent_id, date_range),
          trend_data: trend_analysis(date_range)
        }
      end
    end

    def ticket_metrics(agent_id = nil, date_range = 30.days)
      base_query = Ticket.where(created_at: date_range.ago..Time.current)
      base_query = base_query.where(assigned_agent_id: agent_id) if agent_id

      {
        total_tickets: base_query.count,
        open_tickets: base_query.where(status: 'open').count,
        resolved_tickets: base_query.where(status: 'resolved').count,
        avg_resolution_time: calculate_avg_resolution_time(base_query),
        priority_distribution: priority_distribution(base_query),
        category_distribution: category_distribution(base_query)
      }
    end

    def ai_performance_metrics(date_range = 30.days)
      tickets_with_ai = Ticket.where(
        created_at: date_range.ago..Time.current,
        ai_analysis: { '$exists' => true }
      )

      total_analyzed = tickets_with_ai.count
      return {} if total_analyzed.zero?

      {
        total_analyzed: total_analyzed,
        accuracy_score: calculate_ai_accuracy(tickets_with_ai),
        confidence_distribution: confidence_distribution(tickets_with_ai),
        processing_time: avg_ai_processing_time(tickets_with_ai),
        suggestion_acceptance_rate: suggestion_acceptance_rate(tickets_with_ai)
      }
    end

    def agent_performance_metrics(agent_id = nil, date_range = 30.days)
      return {} unless agent_id

      agent_tickets = Ticket.where(
        assigned_agent_id: agent_id,
        created_at: date_range.ago..Time.current
      )

      {
        tickets_handled: agent_tickets.count,
        avg_response_time: calculate_avg_response_time(agent_tickets),
        resolution_rate: calculate_resolution_rate(agent_tickets),
        customer_satisfaction: calculate_satisfaction_score(agent_tickets),
        productivity_score: calculate_productivity_score(agent_tickets)
      }
    end

    def trend_analysis(date_range = 30.days)
      daily_data = []
      
      date_range.to_i.times do |i|
        date = i.days.ago.beginning_of_day
        next_date = date + 1.day
        
        daily_tickets = Ticket.where(created_at: date..next_date)
        
        daily_data << {
          date: date.strftime('%Y-%m-%d'),
          tickets_created: daily_tickets.count,
          tickets_resolved: daily_tickets.where(status: 'resolved').count,
          ai_analyzed: daily_tickets.where(ai_analysis: { '$exists' => true }).count
        }
      end

      daily_data.reverse
    end

    def real_time_stats
      {
        active_agents: Agent.where(last_seen_at: 15.minutes.ago..Time.current).count,
        pending_tickets: Ticket.where(status: 'open').count,
        ai_queue_size: BackgroundJob.where(job_type: 'ai_analysis', status: 'pending').count,
        avg_wait_time: calculate_current_wait_time
      }
    end

    private

    def calculate_avg_resolution_time(tickets)
      resolved_tickets = tickets.where(status: 'resolved', resolved_at: { '$exists' => true })
      return 0 if resolved_tickets.empty?

      total_time = resolved_tickets.sum do |ticket|
        (ticket.resolved_at - ticket.created_at).to_i
      end

      (total_time / resolved_tickets.count / 3600.0).round(2) # Convert to hours
    end

    def priority_distribution(tickets)
      tickets.group_by(&:priority).transform_values(&:count)
    end

    def category_distribution(tickets)
      tickets.where(ai_analysis: { '$exists' => true })
             .group_by { |t| t.ai_analysis['category'] }
             .transform_values(&:count)
    end

    def calculate_ai_accuracy(tickets)
      # Compare AI predictions with final agent classifications
      accurate_predictions = tickets.select do |ticket|
        next false unless ticket.ai_analysis && ticket.final_category
        ticket.ai_analysis['category'] == ticket.final_category
      end

      return 0 if tickets.empty?
      (accurate_predictions.count.to_f / tickets.count * 100).round(2)
    end

    def confidence_distribution(tickets)
      confidences = tickets.filter_map do |ticket|
        ticket.ai_analysis&.dig('confidence_score')
      end

      return {} if confidences.empty?

      {
        high: confidences.count { |c| c >= 0.8 },
        medium: confidences.count { |c| c >= 0.5 && c < 0.8 },
        low: confidences.count { |c| c < 0.5 }
      }
    end

    def avg_ai_processing_time(tickets)
      processing_times = tickets.filter_map do |ticket|
        ticket.ai_analysis&.dig('processing_time_ms')
      end

      return 0 if processing_times.empty?
      (processing_times.sum.to_f / processing_times.count).round(2)
    end

    def suggestion_acceptance_rate(tickets)
      tickets_with_suggestions = tickets.select { |t| t.ai_analysis&.dig('suggested_response') }
      return 0 if tickets_with_suggestions.empty?

      accepted = tickets_with_suggestions.count { |t| t.ai_suggestion_used == true }
      (accepted.to_f / tickets_with_suggestions.count * 100).round(2)
    end

    def calculate_avg_response_time(tickets)
      response_times = tickets.filter_map do |ticket|
        next unless ticket.first_response_at
        (ticket.first_response_at - ticket.created_at).to_i
      end

      return 0 if response_times.empty?
      (response_times.sum.to_f / response_times.count / 3600.0).round(2) # Hours
    end

    def calculate_resolution_rate(tickets)
      return 0 if tickets.empty?
      resolved_count = tickets.where(status: 'resolved').count
      (resolved_count.to_f / tickets.count * 100).round(2)
    end

    def calculate_satisfaction_score(tickets)
      # Mock implementation - in real app, this would come from customer feedback
      scores = tickets.filter_map(&:satisfaction_score)
      return 0 if scores.empty?
      (scores.sum.to_f / scores.count).round(2)
    end

    def calculate_productivity_score(tickets)
      # Composite score based on resolution time, quality, and volume
      return 0 if tickets.empty?
      
      base_score = 50
      base_score += [tickets.count * 2, 30].min # Volume bonus (max 30)
      base_score += calculate_resolution_rate(tickets) * 0.2 # Quality bonus
      base_score -= calculate_avg_resolution_time(tickets) * 2 # Time penalty
      
      [[base_score, 0].max, 100].min.round(2)
    end

    def calculate_current_wait_time
      open_tickets = Ticket.where(status: 'open')
      return 0 if open_tickets.empty?

      wait_times = open_tickets.map { |t| (Time.current - t.created_at).to_i }
      (wait_times.sum.to_f / wait_times.count / 60.0).round(2) # Minutes
    end
  end
end
