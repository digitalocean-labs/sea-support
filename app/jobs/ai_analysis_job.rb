class AiAnalysisJob < ApplicationJob
  queue_as :ai_analysis
  
  # Retry up to 3 times with exponential backoff for transient failures
  retry_on AiService::RateLimitError, wait: :exponentially_longer, attempts: 3
  retry_on AiService::ApiError, wait: :exponentially_longer, attempts: 2
  
  # Don't retry on persistent errors
  discard_on AiService::AiError
  
  # Main job execution
  def perform(ticket_id)
    begin
      ticket = Ticket.find(ticket_id)
    rescue Mongoid::Errors::DocumentNotFound => e
      Rails.logger.error "❌ AI analysis job failed: Ticket with ID #{ticket_id} not found"
      return
    end
    
    # Create BackgroundJob instance for detailed tracking
    @background_job = BackgroundJob.create!(
      ticket: ticket,
      job_type: 'ai_analysis',
      status: 'processing',
      activejob_id: job_id,
      ai_endpoint: 'agent',
      processing_steps: [],
      console_logs: []
    )
    
    Rails.logger.info "🤖 Starting AI analysis for ticket #{ticket.ticket_number}"
    @background_job.add_console_log("Starting AI analysis for ticket #{ticket.ticket_number}", 'INFO')
    
    # Update both status tracking systems
    update_analysis_status(ticket, 'processing', @background_job.id)
    
    begin
      # Record start time for performance tracking
      start_time = Time.current
      @background_job.add_processing_step('ai_analysis_start', 'Starting AI analysis', 'in_progress')
      
      # Perform AI analysis with BackgroundJob instance for detailed tracking
      ai_service = AiService.new(true, @background_job) # Enable debug mode and pass background job
      analysis_result = ai_service.analyze_ticket(ticket, true) # Include response generation
      
      # Calculate total duration
      total_duration_ms = ((Time.current - start_time) * 1000).to_i
      
      if analysis_result
        # Mark BackgroundJob as completed with final data
        @background_job.mark_completed({
          total_duration_ms: total_duration_ms,
          confidence_score: analysis_result[:confidence_score],
          suggested_priority: analysis_result[:priority_suggestion],
          sentiment_detected: analysis_result[:sentiment],
          tags_generated: analysis_result[:tags] || [],
          has_suggested_response: analysis_result[:suggested_response].present?
        })
        
        # Update status to completed
        update_analysis_status(ticket, 'completed', @background_job.id)
        
        # Log completion activity
        ticket.activities.create!(
          performed_by: 'AI System',
          action: 'ai_analyzed',
          description: "AI analysis completed with #{(analysis_result[:confidence_score] || 0) * 100}% confidence",
          performed_at: Time.current
        )
        
        Rails.logger.info "✅ AI analysis completed for ticket #{ticket.ticket_number}"
        @background_job.add_console_log("AI analysis completed successfully", 'INFO')
      else
        # Analysis returned nil - treat as failure
        @background_job.mark_failed(StandardError.new('AI analysis returned no results'))
        update_analysis_status(ticket, 'failed', @background_job.id, 'AI analysis returned no results')
        Rails.logger.error "❌ AI analysis failed for ticket #{ticket.ticket_number}: No results returned"
      end
      
    rescue AiService::RateLimitError => e
      # This will trigger retry via retry_on
      @background_job.mark_failed(e, @background_job.retry_count + 1)
      update_analysis_status(ticket, 'retrying', @background_job.id, "Rate limited: #{e.message}")
      Rails.logger.warn "⏱️ AI analysis rate limited for ticket #{ticket.ticket_number}: #{e.message}"
      @background_job.add_console_log("Rate limited, will retry: #{e.message}", 'WARN')
      raise # Re-raise to trigger retry
      
    rescue AiService::ApiError => e
      # This will trigger retry via retry_on  
      @background_job.mark_failed(e, @background_job.retry_count + 1)
      update_analysis_status(ticket, 'retrying', @background_job.id, "API error: #{e.message}")
      Rails.logger.error "🔧 AI analysis API error for ticket #{ticket.ticket_number}: #{e.message}"
      @background_job.add_console_log("API error, will retry: #{e.message}", 'ERROR')
      raise # Re-raise to trigger retry
      
    rescue AiService::AiError => e
      # This will be discarded (no retry)
      @background_job.mark_failed(e)
      update_analysis_status(ticket, 'failed', @background_job.id, "AI error: #{e.message}")
      Rails.logger.error "❌ AI analysis failed permanently for ticket #{ticket.ticket_number}: #{e.message}"
      @background_job.add_console_log("Permanent AI error: #{e.message}", 'ERROR')
      
    rescue StandardError => e
      # Unexpected error - update status and re-raise for default retry behavior
      @background_job.mark_failed(e)
      update_analysis_status(ticket, 'failed', @background_job.id, "Unexpected error: #{e.message}")
      Rails.logger.error "💥 Unexpected error in AI analysis for ticket #{ticket.ticket_number}: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      @background_job.add_console_log("Unexpected error: #{e.message}", 'ERROR')
      raise
    end
  end
  
  # Handle final failure after all retries exhausted
  def rescue_with_handler(exception)
    if arguments.first
      ticket = Ticket.find(arguments.first) rescue nil
      if ticket && @background_job
        @background_job.mark_failed(exception)
        update_analysis_status(ticket, 'failed', @background_job.id, "All retries exhausted: #{exception.message}")
        @background_job.add_console_log("All retries exhausted: #{exception.message}", 'ERROR')
      end
      
      # Log final failure activity
      ticket&.activities&.create!(
        performed_by: 'AI System',
        action: 'ai_analysis_failed',
        description: "AI analysis failed after retries: #{exception.class.name}",
        performed_at: Time.current
      )
      
      Rails.logger.error "💀 AI analysis permanently failed for ticket #{ticket&.ticket_number} after retries: #{exception.message}"
    end
    
    super
  end
  
  private
  
  # Update the AI analysis status and error message
  def update_analysis_status(ticket, status, background_job_id = nil, error_message = nil)
    # Ensure ai_analysis exists
    unless ticket.ai_analysis
      ticket.create_ai_analysis(
        processed_at: Time.current,
        confidence_score: 0.0
      )
    end
    
    # Update status and error
    update_data = {
      analysis_status: status,
      status_updated_at: Time.current,
      job_id: job_id # Store ActiveJob ID for correlation
    }
    
    # Link to BackgroundJob for detailed tracking
    if background_job_id
      update_data[:background_job_id] = background_job_id
    end
    
    if error_message
      update_data[:error_message] = error_message
    else
      # Clear error message on success
      update_data[:error_message] = nil if status == 'completed'
    end
    
    ticket.ai_analysis.update(update_data)
    
    Rails.logger.info "📊 Updated AI analysis status for ticket #{ticket.ticket_number}: #{status}"
  end
end