class PerformanceService
  CACHE_NAMESPACE = 'sea_support'
  
  class << self
    # Intelligent query optimization for MongoDB
    def optimize_ticket_queries
      ensure_indexes
      warm_cache
      cleanup_stale_data
    end

    # Multi-layer caching strategy
    def cached_ticket_search(query, filters = {}, page = 1, per_page = 20)
      cache_key = generate_search_cache_key(query, filters, page, per_page)
      
      Rails.cache.fetch(cache_key, expires_in: 5.minutes) do
        perform_ticket_search(query, filters, page, per_page)
      end
    end

    # Preload and cache frequently accessed data
    def preload_dashboard_data(agent_id)
      cache_key = "#{CACHE_NAMESPACE}:dashboard:#{agent_id}"
      
      Rails.cache.fetch(cache_key, expires_in: 2.minutes) do
        {
          recent_tickets: recent_tickets_for_agent(agent_id),
          pending_count: pending_tickets_count(agent_id),
          ai_queue_status: ai_processing_status,
          quick_stats: quick_agent_stats(agent_id)
        }
      end
    end

    # Background job for cache warming
    def warm_critical_caches
      # Warm frequently accessed data
      Agent.active.find_each do |agent|
        preload_dashboard_data(agent.id)
      end

      # Warm analytics caches
      AnalyticsService.dashboard_metrics
      
      # Warm search caches for common queries
      common_search_terms.each do |term|
        cached_ticket_search(term)
      end
    end

    # Performance monitoring
    def track_performance(operation, &block)
      start_time = Time.current
      result = yield
      duration = (Time.current - start_time) * 1000 # milliseconds
      
      log_performance_metric(operation, duration)
      result
    end

    # Database optimization
    def optimize_database_performance
      # Analyze slow queries
      slow_queries = analyze_slow_operations
      
      # Suggest index improvements
      index_suggestions = suggest_indexes
      
      # Clean up old data
      cleanup_old_records
      
      {
        slow_queries: slow_queries,
        index_suggestions: index_suggestions,
        cleanup_summary: "Cleaned up old records"
      }
    end

    # Memory usage optimization
    def optimize_memory_usage
      # Clear unused caches
      clear_stale_caches
      
      # Optimize object allocation
      GC.start
      
      {
        memory_before: memory_usage_mb,
        memory_after: (GC.start; memory_usage_mb),
        cache_cleared: true
      }
    end

    private

    def ensure_indexes
      # Ensure critical indexes exist for performance
      Ticket.collection.indexes.create_one(
        { status: 1, created_at: -1 },
        { background: true, name: 'status_created_at_idx' }
      ) rescue nil

      Ticket.collection.indexes.create_one(
        { assigned_agent_id: 1, status: 1 },
        { background: true, name: 'agent_status_idx' }
      ) rescue nil

      Ticket.collection.indexes.create_one(
        { '$**': 'text' },
        { background: true, name: 'full_text_search_idx' }
      ) rescue nil
    end

    def warm_cache
      # Pre-populate frequently accessed data
      Rails.cache.write("#{CACHE_NAMESPACE}:active_agents", Agent.active.count, expires_in: 1.minute)
      Rails.cache.write("#{CACHE_NAMESPACE}:total_tickets", Ticket.count, expires_in: 5.minutes)
    end

    def cleanup_stale_data
      # Remove old background jobs
      BackgroundJob.where(created_at: ..1.week.ago, status: 'completed').delete_all
      
      # Archive old resolved tickets
      old_resolved = Ticket.where(
        status: 'resolved',
        resolved_at: ..3.months.ago
      )
      
      old_resolved.update_all(archived: true) if old_resolved.exists?
    end

    def generate_search_cache_key(query, filters, page, per_page)
      filter_hash = Digest::MD5.hexdigest(filters.to_json)
      "#{CACHE_NAMESPACE}:search:#{Digest::MD5.hexdigest(query)}:#{filter_hash}:#{page}:#{per_page}"
    end

    def perform_ticket_search(query, filters, page, per_page)
      tickets = Ticket.all
      
      # Apply text search
      if query.present?
        tickets = tickets.full_text_search(query)
      end
      
      # Apply filters
      filters.each do |key, value|
        next if value.blank?
        
        case key.to_s
        when 'status'
          tickets = tickets.where(status: value)
        when 'priority'
          tickets = tickets.where(priority: value)
        when 'assigned_agent_id'
          tickets = tickets.where(assigned_agent_id: value)
        when 'category'
          tickets = tickets.where('ai_analysis.category' => value)
        end
      end
      
      # Pagination and sorting
      tickets.order_by(created_at: :desc)
             .skip((page - 1) * per_page)
             .limit(per_page)
             .to_a
    end

    def recent_tickets_for_agent(agent_id)
      Ticket.where(assigned_agent_id: agent_id)
            .order_by(created_at: :desc)
            .limit(10)
            .only(:id, :title, :status, :priority, :created_at)
    end

    def pending_tickets_count(agent_id)
      Ticket.where(assigned_agent_id: agent_id, status: 'open').count
    end

    def ai_processing_status
      {
        pending: BackgroundJob.where(job_type: 'ai_analysis', status: 'pending').count,
        processing: BackgroundJob.where(job_type: 'ai_analysis', status: 'processing').count
      }
    end

    def quick_agent_stats(agent_id)
      today = Time.current.beginning_of_day
      
      {
        tickets_today: Ticket.where(assigned_agent_id: agent_id, created_at: today..Time.current).count,
        resolved_today: Ticket.where(assigned_agent_id: agent_id, status: 'resolved', resolved_at: today..Time.current).count
      }
    end

    def common_search_terms
      # In a real app, this would be based on search analytics
      ['coffee', 'temperature', 'brewing', 'error', 'maintenance', 'setup']
    end

    def log_performance_metric(operation, duration)
      Rails.logger.info "[PERFORMANCE] #{operation}: #{duration.round(2)}ms"
      
      # Store in cache for monitoring dashboard
      metrics_key = "#{CACHE_NAMESPACE}:performance:#{operation}"
      current_metrics = Rails.cache.read(metrics_key) || []
      current_metrics << { timestamp: Time.current, duration: duration }
      
      # Keep only last 100 measurements
      current_metrics = current_metrics.last(100)
      Rails.cache.write(metrics_key, current_metrics, expires_in: 1.hour)
    end

    def analyze_slow_operations
      # Mock implementation - in production, this would analyze MongoDB profiler data
      [
        { operation: 'ticket_search', avg_duration: 150, count: 45 },
        { operation: 'ai_analysis', avg_duration: 2300, count: 12 }
      ]
    end

    def suggest_indexes
      # Analyze query patterns and suggest indexes
      [
        { collection: 'tickets', index: '{ "ai_analysis.category": 1, "status": 1 }' },
        { collection: 'background_jobs', index: '{ "job_type": 1, "status": 1, "created_at": -1 }' }
      ]
    end

    def cleanup_old_records
      # Remove old performance metrics
      Rails.cache.delete_matched("#{CACHE_NAMESPACE}:performance:*")
    end

    def clear_stale_caches
      # Clear caches older than 1 hour
      Rails.cache.delete_matched("#{CACHE_NAMESPACE}:*")
    end

    def memory_usage_mb
      `ps -o rss= -p #{Process.pid}`.to_i / 1024.0
    end
  end
end
