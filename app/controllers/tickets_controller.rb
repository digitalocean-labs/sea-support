# LEARNING NOTE: Tickets Controller
# This controller handles all CRUD operations for support tickets
# It includes search, filtering, AI analysis, and activity logging
class TicketsController < ApplicationController
  before_action :set_ticket, only: [ :show, :edit, :update, :destroy, :analyze, :generate_response, :reset_analysis, :send_ai_response, :ai_analysis, :debug_rag, :debug_progress, :debug_logs ]

  def index
    # LEARNING NOTE: Ticket Listing with Search and Filters
    # Build query based on search parameters and user permissions

    @q = params[:q] || {}
    @tickets = Ticket.all

    # Search by ticket number or subject
    if @q[:search].present?
      search_term = @q[:search]
      @tickets = @tickets.where(
        "$or" => [
          { ticket_number: /#{Regexp.escape(search_term)}/i },
          { subject: /#{Regexp.escape(search_term)}/i }
        ]
      )
    end

    # Filter by status
    if @q[:status].present? && @q[:status] != "all"
      @tickets = @tickets.where(status: @q[:status])
    end

    # Filter by priority
    if @q[:priority].present? && @q[:priority] != "all"
      @tickets = @tickets.where(priority: @q[:priority])
    end

    # Filter by category
    if @q[:issue_category].present? && @q[:issue_category] != "all"
      @tickets = @tickets.where(issue_category: @q[:issue_category])
    end

    # Filter by AI response status
    if @q[:ai_response_status].present? && @q[:ai_response_status] != "all"
      case @q[:ai_response_status]
      when "has_response"
        @tickets = @tickets.where("ai_analysis.suggested_response" => { "$exists" => true, "$nin" => [ nil, "" ] })
      when "no_response"
        @tickets = @tickets.where("$or" => [
          { ai_analysis: { "$exists" => false } },
          { "ai_analysis.suggested_response" => { "$exists" => false } },
          { "ai_analysis.suggested_response" => { "$in" => [ nil, "" ] } }
        ])
      when "high_confidence"
        @tickets = @tickets.where("ai_analysis.confidence_score" => { "$gte" => 0.85 })
      when "auto_respondable"
        # Auto-respondable: has suggested response AND high confidence
        @tickets = @tickets.where(
          "ai_analysis.suggested_response" => { "$exists" => true, "$nin" => [ nil, "" ] },
          "ai_analysis.confidence_score" => { "$gte" => 0.85 }
        )
      end
    end

    # Filter by assigned agent (if not admin, show only assigned tickets)
    if current_agent.admin?
      # Admin can filter by specific agent or see all
      if @q[:assigned_agent_id].present? && @q[:assigned_agent_id] != "all"
        @tickets = @tickets.where(assigned_agent_id: @q[:assigned_agent_id])
      end
    else
      # Non-admin agents only see their assigned tickets
      @tickets = @tickets.where(assigned_agent_id: current_agent.id)
    end

    # Handle sorting
    sort_field = params[:sort] || "created_at"
    sort_direction = params[:direction] || "desc"

    # Validate sort field to prevent injection
    valid_sort_fields = %w[created_at updated_at status priority subject customer_name]
    sort_field = "created_at" unless valid_sort_fields.include?(sort_field)

    # Validate sort direction
    sort_direction = "desc" unless %w[asc desc].include?(sort_direction)

    # Apply sorting with special handling for embedded fields
    if sort_field == "customer_name"
      # Sort by embedded document field
      @tickets = @tickets.order_by("customer_info.customer_name" => sort_direction.to_sym)
    else
      # Regular field sorting
      @tickets = @tickets.order_by(sort_field.to_sym => sort_direction.to_sym)
    end

    # Store sort params for view
    @sort_field = sort_field
    @sort_direction = sort_direction

    # MOODBREW FEATURE: Show ticket statistics with AI workflow metrics
    total_count = Ticket.count
    analyzed_count = Ticket.where(:ai_analysis.exists => true).count

    @stats = {
      total: total_count,
      new: Ticket.where(status: "new").count,
      in_progress: Ticket.where(status: "in_progress").count,
      resolved: Ticket.where(status: "resolved").count,
      urgent: Ticket.where(priority: "urgent").count,
      ai_analyzed: analyzed_count,
      unanalyzed: total_count - analyzed_count,
      analysis_progress: total_count > 0 ? ((analyzed_count.to_f / total_count) * 100).round : 0
    }

    # Get all agents for filter dropdown
    @agents = Agent.all.order_by(name: :asc)
  end

  def show
    # LEARNING NOTE: Display Ticket Details
    # Show full ticket information with messages and activity timeline

    # Mark ticket as viewed by current agent
    @ticket.activities.create!(
      performed_by: current_agent.display_name,
      action: "viewed",
      description: "Ticket viewed by #{current_agent.display_name}",
      performed_at: Time.current
    ) unless @ticket.activities.where(
      performed_by: current_agent.display_name,
      action: "viewed"
    ).exists?
  end

  def new
    # LEARNING NOTE: New Ticket Form
    # Create empty ticket for form binding
    @ticket = Ticket.new
    @ticket.build_customer_info if @ticket.customer_info.blank?
  end

  def create
    # LEARNING NOTE: Ticket Creation Flow
    # 1. Create ticket with form parameters
    # 2. Generate unique ticket number
    # 3. Assign to current agent or auto-assign
    # 4. Run AI analysis if enabled
    # 5. Log creation activity

    @ticket = Ticket.new(ticket_params)
    @ticket.created_by = current_agent

    # Auto-assign to current agent if not specified
    @ticket.assigned_agent = current_agent unless @ticket.assigned_agent_id.present?

    if @ticket.save
      # Log ticket creation
      @ticket.activities.create!(
        performed_by: current_agent.display_name,
        action: "created",
        description: "Ticket created by #{current_agent.display_name}",
        performed_at: Time.current
      )

      # Add initial customer message if description provided
      if @ticket.description.present?
        @ticket.messages.create!(
          sender: "customer",
          sender_name: @ticket.customer_info&.customer_name || "Customer",
          content: @ticket.description,
          sent_at: Time.current
        )
      end

      # MOODBREW FEATURE: Queue AI analysis in background for faster response
      begin
        # Create AI analysis record with queued status
        @ticket.build_ai_analysis unless @ticket.ai_analysis
        @ticket.ai_analysis.analysis_status = "queued"
        @ticket.ai_analysis.status_updated_at = Time.current
        @ticket.ai_analysis.save!

        # Queue the background job
        job = AiAnalysisJob.perform_later(@ticket.id)

        # Store job ID for tracking
        @ticket.ai_analysis.update(job_id: job.job_id)

        # Log queuing activity
        @ticket.activities.create!(
          performed_by: "System",
          action: "ai_queued",
          description: "AI analysis queued for background processing",
          performed_at: Time.current
        )

        Rails.logger.info "🚀 Queued AI analysis job #{job.job_id} for ticket #{@ticket.ticket_number}"
      rescue => e
        Rails.logger.error "Failed to queue AI analysis for ticket #{@ticket.ticket_number}: #{e.message}"
        # Don't fail ticket creation if AI queuing fails - just log it
      end

      redirect_to @ticket, notice: "✅ Ticket #{@ticket.ticket_number} created successfully!"
    else
      @ticket.build_customer_info if @ticket.customer_info.blank?
      flash.now[:alert] = "Please fix the errors below."
      render :new, status: :unprocessable_content
    end
  end

  def edit
    # LEARNING NOTE: Edit Ticket Form
    # Load ticket for editing with validation
    @ticket.build_customer_info if @ticket.customer_info.blank?
  end

  def update
    # LEARNING NOTE: Ticket Update Flow
    # 1. Update ticket with new parameters
    # 2. Log changes as activities
    # 3. Handle status changes
    # 4. Send notifications if needed

    old_status = @ticket.status
    old_priority = @ticket.priority
    old_assigned_agent = @ticket.assigned_agent

    if @ticket.update(ticket_params)
      changes_logged = []

      # Log status change
      if old_status != @ticket.status
        @ticket.activities.create!(
          performed_by: current_agent.display_name,
          action: "status_changed",
          description: "Status changed from '#{old_status}' to '#{@ticket.status}' by #{current_agent.display_name}",
          performed_at: Time.current
        )
        changes_logged << "status"
      end

      # Log priority change
      if old_priority != @ticket.priority
        @ticket.activities.create!(
          performed_by: current_agent.display_name,
          action: "priority_changed",
          description: "Priority changed from '#{old_priority}' to '#{@ticket.priority}' by #{current_agent.display_name}",
          performed_at: Time.current
        )
        changes_logged << "priority"
      end

      # Log assignment change
      if old_assigned_agent != @ticket.assigned_agent
        old_name = old_assigned_agent&.display_name || "Unassigned"
        new_name = @ticket.assigned_agent&.display_name || "Unassigned"

        @ticket.activities.create!(
          performed_by: current_agent.display_name,
          action: "assigned",
          description: "Assigned from '#{old_name}' to '#{new_name}' by #{current_agent.display_name}",
          performed_at: Time.current
        )
        changes_logged << "assignment"
      end

      # Log general update if no specific changes
      if changes_logged.empty?
        @ticket.activities.create!(
          performed_by: current_agent.display_name,
          action: "updated",
          description: "Ticket updated by #{current_agent.display_name}",
          performed_at: Time.current
        )
      end

      success_message = "✅ Ticket #{@ticket.ticket_number} updated successfully!"
      success_message += " (#{changes_logged.join(', ')} changed)" if changes_logged.any?

      redirect_to @ticket, notice: success_message
    else
      @ticket.build_customer_info if @ticket.customer_info.blank?
      flash.now[:alert] = "Please fix the errors below."
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    # LEARNING NOTE: Ticket Deletion (Admin Only)
    # Only admins should be able to delete tickets for audit purposes

    unless current_agent.admin?
      redirect_to tickets_path, alert: "❌ Only administrators can delete tickets."
      return
    end

    ticket_number = @ticket.ticket_number
    @ticket.destroy

    redirect_to tickets_path, notice: "🗑️ Ticket #{ticket_number} has been deleted."
  end

  def analyze
    # LEARNING NOTE: Manual AI Analysis Action - Now Using Background Jobs
    # Allow agents to trigger AI analysis on-demand via background job queue

    begin
      # Check if analysis is already in progress to prevent duplicate jobs
      if @ticket.ai_analysis&.in_progress?
        redirect_to @ticket, alert: "⏳ AI analysis is already in progress for this ticket."
        return
      end

      # Create or update AI analysis record with queued status
      @ticket.build_ai_analysis unless @ticket.ai_analysis
      @ticket.ai_analysis.analysis_status = "queued"
      @ticket.ai_analysis.status_updated_at = Time.current
      @ticket.ai_analysis.error_message = nil
      @ticket.ai_analysis.save!

      # Queue the background job
      job = AiAnalysisJob.perform_later(@ticket.id)

      # Store job ID for tracking
      @ticket.ai_analysis.update(job_id: job.job_id)

      # Log the manual analysis request
      @ticket.activities.create!(
        performed_by: current_agent.display_name,
        action: "ai_queued",
        description: "Manual AI analysis queued by #{current_agent.display_name}",
        performed_at: Time.current
      )

      Rails.logger.info "🚀 Queued manual AI analysis job #{job.job_id} for ticket #{@ticket.ticket_number}"
      redirect_to @ticket, notice: "🤖 AI analysis has been queued! Check the status below or visit the Background Jobs dashboard."

    rescue => e
      Rails.logger.error "Failed to queue manual AI analysis for ticket #{@ticket.ticket_number}: #{e.message}"
      redirect_to @ticket, alert: "❌ Failed to queue AI analysis. Please try again or contact support."
    end
  end

  def generate_response
    # LEARNING NOTE: Generate Customer Response Action
    # Allow agents to generate AI-powered customer responses

    begin
      ai_service = AiService.new(true) # Enable debug mode
      response_text = ai_service.generate_response(@ticket)

      if response_text.present?
        # Update the AI analysis with the suggested response
        if @ticket.ai_analysis
          @ticket.ai_analysis.update(suggested_response: response_text)
        else
          # Create AI analysis with just the response if no analysis exists
          @ticket.create_ai_analysis(
            suggested_response: response_text,
            confidence_score: 0.8,
            processed_at: Time.current
          )
        end

        # Log the response generation request
        @ticket.activities.create!(
          performed_by: current_agent.display_name,
          action: "ai_response_generated",
          description: "AI customer response generated by #{current_agent.display_name}",
          performed_at: Time.current
        )

        redirect_to @ticket, notice: "✍️ AI response generated successfully!"
      else
        redirect_to @ticket, alert: "❌ Failed to generate AI response. Please try again."
      end

    rescue AiService::RateLimitError => e
      redirect_to @ticket, alert: "⏱️ AI service is rate limited. Please try again in a few minutes."
    rescue AiService::ApiError => e
      redirect_to @ticket, alert: "🔧 AI service is temporarily unavailable. Please try again later."
    rescue => e
      Rails.logger.error "AI response generation failed for ticket #{@ticket.ticket_number}: #{e.message}"
      redirect_to @ticket, alert: "❌ Failed to generate AI response. Please try again or contact support."
    end
  end

  def reset_analysis
    # LEARNING NOTE: Reset AI Analysis Action
    # Allow agents to clear AI analysis and start fresh

    if @ticket.ai_analysis.present?
      @ticket.ai_analysis.destroy

      # Log the reset action
      @ticket.activities.create!(
        performed_by: current_agent.display_name,
        action: "ai_analysis_reset",
        description: "AI analysis cleared by #{current_agent.display_name}",
        performed_at: Time.current
      )

      redirect_to @ticket, notice: "🗑️ AI analysis has been reset. You can now run a fresh analysis."
    else
      redirect_to @ticket, alert: "❌ No AI analysis found to reset."
    end
  end

  def send_ai_response
    # LEARNING NOTE: Send AI Response Action
    # Logs the AI-suggested response as an agent message (internal tracking only)

    response_content = params[:response_content]

    if response_content.blank?
      redirect_to @ticket, alert: "❌ Response content cannot be empty."
      return
    end

    # Create the message as an agent response
    message = @ticket.messages.create!(
      sender: "agent",
      sender_name: current_agent.display_name,
      content: response_content,
      sent_at: Time.current,
      is_ai_generated: true,  # Mark as AI-generated
      agent_approved: true     # Agent reviewed and approved
    )

    # Update ticket status to in_progress (agent has responded)
    if @ticket.status == "new"
      @ticket.update(status: "in_progress")
    end

    # Log the activity
    @ticket.activities.create!(
      performed_by: current_agent.display_name,
      action: "ai_response_sent",
      description: "AI-suggested response sent by #{current_agent.display_name}",
      performed_at: Time.current
    )

    redirect_to @ticket, notice: "✅ Response logged successfully! Remember to send it to the customer through your communication channel."
  end

  def ai_analysis
    # LEARNING NOTE: JSON API Endpoint for AI Analysis
    # Returns AI analysis data for the sidebar display

    respond_to do |format|
      format.json do
        if @ticket.ai_analysis.present?
          render json: {
            confidence_score: @ticket.ai_analysis.confidence_score,
            summary: @ticket.ai_analysis.summary,
            sentiment: @ticket.ai_analysis.sentiment,
            tags: @ticket.ai_analysis.tags || [],
            suggested_response: @ticket.ai_analysis.suggested_response,
            source_files: @ticket.ai_analysis.source_files || [],
            processed_at: @ticket.ai_analysis.processed_at,
            processing_time_ms: @ticket.ai_analysis.processing_time_ms
          }
        else
          render json: { error: "No AI analysis found" }, status: 404
        end
      end
    end
  end

  def analyze_all
    # LEARNING NOTE: Bulk AI Analysis Action - Now Using Background Jobs
    # Queue individual background jobs for each ticket and track via job statuses

    begin
      # Check if we should analyze unanalyzed tickets or re-analyze all tickets
      unanalyzed_tickets = Ticket.where(:ai_analysis.exists => false)

      if unanalyzed_tickets.any?
        # Process only unanalyzed tickets
        tickets_to_process = unanalyzed_tickets
        operation_type = "analysis"
      else
        # Re-analyze all tickets if none are unanalyzed (exclude in-progress jobs)
        tickets_to_process = Ticket.where.not("ai_analysis.analysis_status" => [ "queued", "processing", "retrying" ])
        operation_type = "re-analysis"
      end

      if tickets_to_process.empty?
        redirect_to tickets_path, alert: "❓ No tickets found to process!"
        return
      end

      # Safeguard: Limit bulk operations to prevent queue overwhelming
      max_bulk_size = 100
      if tickets_to_process.count > max_bulk_size
        redirect_to tickets_path, alert: "⚠️ Too many tickets (#{tickets_to_process.count}). Bulk operations limited to #{max_bulk_size} tickets. Please filter or process in batches."
        return
      end

      # Initialize progress tracking in session
      total_count = tickets_to_process.count
      queued_jobs = []

      # Queue jobs for all tickets
      tickets_to_process.each do |ticket|
        # Skip if already in progress
        next if ticket.ai_analysis&.in_progress?

        # Create or update AI analysis record with queued status
        ticket.build_ai_analysis unless ticket.ai_analysis
        ticket.ai_analysis.analysis_status = "queued"
        ticket.ai_analysis.status_updated_at = Time.current
        ticket.ai_analysis.error_message = nil
        ticket.ai_analysis.save!

        # Queue the background job
        job = AiAnalysisJob.perform_later(ticket.id)

        # Store job ID for tracking
        ticket.ai_analysis.update(job_id: job.job_id)
        queued_jobs << { ticket_number: ticket.ticket_number, job_id: job.job_id }

        # Log the bulk queuing activity
        action_type = operation_type == "re-analysis" ? "ai_reanalysis_queued_bulk" : "ai_analysis_queued_bulk"
        description_prefix = operation_type == "re-analysis" ? "Bulk AI re-analysis" : "Bulk AI analysis"

        ticket.activities.create!(
          performed_by: current_agent.display_name,
          action: action_type,
          description: "#{description_prefix} queued by #{current_agent.display_name}",
          performed_at: Time.current
        )
      end

      # Store bulk operation info in session for progress tracking
      session[:bulk_analysis] = {
        total: queued_jobs.count,
        queued_at: Time.current.to_i,
        operation_type: operation_type,
        status: "queued",
        job_ids: queued_jobs.map { |j| j[:job_id] }
      }

      operation_verb = operation_type == "re-analysis" ? "re-analysis" : "analysis"
      Rails.logger.info "🚀 Queued #{queued_jobs.count} AI #{operation_verb} jobs for bulk operation"

      redirect_to tickets_path, notice: "🤖 Queued #{queued_jobs.count} tickets for AI #{operation_verb}! Visit the Background Jobs dashboard to monitor progress."

    rescue => e
      Rails.logger.error "Bulk analysis queueing failed: #{e.message}"
      redirect_to tickets_path, alert: "❌ Failed to queue bulk analysis. Please try again or contact support."
    end
  end

  def bulk_analysis_progress
    # LEARNING NOTE: Progress Endpoint for AJAX Polling - Updated for Background Jobs
    # Returns JSON with current progress by checking actual job statuses

    bulk_info = session[:bulk_analysis] || { status: "not_started" }

    if bulk_info[:job_ids].present?
      # Count tickets by their AI analysis status
      job_ids = bulk_info[:job_ids]
      total = bulk_info[:total] || job_ids.count

      # Count statuses across all tickets in this bulk operation
      completed_count = Ticket.where("ai_analysis.job_id" => { "$in" => job_ids }, "ai_analysis.analysis_status" => "completed").count
      failed_count = Ticket.where("ai_analysis.job_id" => { "$in" => job_ids }, "ai_analysis.analysis_status" => "failed").count
      processing_count = Ticket.where("ai_analysis.job_id" => { "$in" => job_ids }, "ai_analysis.analysis_status" => [ "queued", "processing", "retrying" ]).count

      processed = completed_count + failed_count
      percentage = total > 0 ? ((processed.to_f / total) * 100).round : 0

      # Determine overall status
      overall_status = if processing_count > 0
                        "in_progress"
      elsif processed == total
                        "completed"
      else
                        bulk_info[:status] || "unknown"
      end

      progress = {
        status: overall_status,
        total: total,
        completed: completed_count,
        failed: failed_count,
        processing: processing_count,
        processed: processed,
        percentage: percentage,
        operation_type: bulk_info[:operation_type] || "analysis"
      }
    else
      progress = bulk_info.merge(percentage: 0)
    end

    render json: progress
  end

  def bulk_apply_responses
    # LEARNING NOTE: Bulk Response Application Action
    # Apply suggested responses to multiple selected tickets

    begin
      ticket_ids = params[:ticket_ids] || []

      if ticket_ids.empty?
        redirect_to tickets_path, alert: "❌ No tickets selected for response application."
        return
      end

      # Find tickets with suggested responses
      tickets = Ticket.in(id: ticket_ids).where(
        "ai_analysis.suggested_response" => { "$exists" => true, "$nin" => [ nil, "" ] }
      )

      if tickets.empty?
        redirect_to tickets_path, alert: "❌ No tickets found with suggested responses."
        return
      end

      # Process each ticket
      applied_count = 0
      failed_count = 0

      tickets.each do |ticket|
        begin
          # Add suggested response as a message from the agent
          ticket.messages.create!(
            sender: "agent",
            sender_name: current_agent.display_name,
            content: ticket.ai_analysis.suggested_response,
            sent_at: Time.current,
            is_ai_generated: true,
            agent_approved: true
          )

          # Update ticket status to in_progress (agent has responded)
          ticket.update(status: "in_progress")

          # Log the response application
          ticket.activities.create!(
            performed_by: current_agent.display_name,
            action: "ai_response_applied",
            description: "AI-suggested response applied by #{current_agent.display_name}",
            performed_at: Time.current
          )

          applied_count += 1

        rescue => e
          Rails.logger.error "Failed to apply response for ticket #{ticket.ticket_number}: #{e.message}"
          failed_count += 1
        end
      end

      # Create success message
      if failed_count == 0
        redirect_to tickets_path, notice: "🚀 Successfully applied responses to #{applied_count} tickets! Customers will receive these responses."
      else
        redirect_to tickets_path, notice: "🚀 Applied responses to #{applied_count} tickets (#{failed_count} failed). Check logs for details."
      end

    rescue => e
      Rails.logger.error "Bulk response application failed: #{e.message}"
      redirect_to tickets_path, alert: "❌ Failed to apply responses. Please try again or contact support."
    end
  end

  def generate_demo_ticket
    # LEARNING NOTE: Demo Ticket Generation Action
    # Uses AI to generate realistic demo ticket data for form population

    begin
      demo_service = DemoTicketService.new
      ticket_data = demo_service.generate_demo_ticket

      Rails.logger.info "🎪 Generated demo ticket: #{ticket_data[:subject]&.truncate(50)}"

      respond_to do |format|
        format.json { render json: ticket_data }
      end

    rescue => e
      Rails.logger.error "Demo ticket generation failed: #{e.message}"

      respond_to do |format|
        format.json {
          render json: {
            error: "Failed to generate demo ticket",
            message: e.message
          }, status: 500
        }
      end
    end
  end

  # Debug endpoints for development/testing
  def debug_rag
    # Return RAG response data for debugging
    respond_to do |format|
      format.json do
        # Ensure ticket is loaded
        if @ticket.nil?
          render json: {
            error: "Ticket not found",
            message: "Unable to load ticket data",
            ticket_id: params[:id]
          }, status: 404
          return
        end

        begin
          debug_data = AiService.get_debug_data(@ticket.id)

          if debug_data && debug_data[:rag_response]
            render json: debug_data[:rag_response]
          else
            render json: {
              error: "No RAG response data found",
              message: "Run AI analysis first to capture RAG data",
              ticket_id: @ticket.id.to_s
            }
          end
        rescue => e
          Rails.logger.error "Debug RAG endpoint error: #{e.message}"
          render json: {
            error: "Debug endpoint error",
            message: e.message,
            ticket_id: @ticket.id.to_s
          }, status: 500
        end
      end
    end
  end

  def debug_progress
    # Return progress/timing data for debugging
    respond_to do |format|
      format.json do
        # Ensure ticket is loaded
        if @ticket.nil?
          render json: {
            error: "Ticket not found",
            message: "Unable to load ticket data",
            steps: [],
            logs: [],
            ticket_id: params[:id]
          }, status: 404
          return
        end

        begin
          debug_data = AiService.get_debug_data(@ticket.id)

          if debug_data && debug_data[:session]
            render json: debug_data[:session]
          else
            render json: {
              error: "No progress data found",
              message: "Run AI analysis to generate progress data",
              steps: [],
              logs: [],
              ticket_id: @ticket.id.to_s
            }
          end
        rescue => e
          Rails.logger.error "Debug progress endpoint error: #{e.message}"
          render json: {
            error: "Debug endpoint error",
            message: e.message,
            steps: [],
            logs: [],
            ticket_id: @ticket.id.to_s
          }, status: 500
        end
      end
    end
  end

  def debug_logs
    # Return console logs for debugging
    respond_to do |format|
      format.json do
        # Ensure ticket is loaded
        if @ticket.nil?
          render json: {
            logs: [],
            error: "Ticket not found",
            message: "Unable to load ticket data",
            ticket_id: params[:id]
          }, status: 404
          return
        end

        begin
          debug_data = AiService.get_debug_data(@ticket.id)

          if debug_data && debug_data[:session] && debug_data[:session][:logs]
            render json: { logs: debug_data[:session][:logs] }
          else
            render json: {
              logs: [],
              message: "No logs available yet. Run AI analysis to generate logs.",
              ticket_id: @ticket.id.to_s
            }
          end
        rescue => e
          Rails.logger.error "Debug logs endpoint error: #{e.message}"
          render json: {
            logs: [],
            error: "Debug endpoint error",
            message: e.message,
            ticket_id: @ticket.id.to_s
          }, status: 500
        end
      end
    end
  end

  private

  def set_ticket
    # LEARNING NOTE: Find Ticket by ID
    # Load ticket and handle not found errors gracefully
    @ticket = Ticket.find(params[:id])
  rescue Mongoid::Errors::DocumentNotFound
    redirect_to tickets_path, alert: "❌ Ticket not found."
  end

  def ticket_params
    # LEARNING NOTE: Strong Parameters for Ticket
    # Allow nested attributes for embedded documents
    params.require(:ticket).permit(
      :subject, :description, :status, :priority, :channel,
      :machine_model, :issue_category, :customer_mood,
      :assigned_agent_id,
      customer_info_attributes: [
        :id, :customer_name, :email, :phone, :account_tier,
        :moodbrew_serial, :purchase_date, :warranty_status
      ]
    )
  end
end
