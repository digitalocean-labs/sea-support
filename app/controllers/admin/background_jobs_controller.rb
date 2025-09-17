class Admin::BackgroundJobsController < ApplicationController
  before_action :ensure_admin

  def index
    # LEARNING NOTE: Background Job Dashboard for Administrators
    # Now uses the BackgroundJob model for comprehensive job tracking

    @page_title = "Background Jobs"

    # Get filter parameters
    @filter_status = params[:status] || "all"
    @filter_date = params[:date] || "all"
    @page = (params[:page] || 1).to_i
    @per_page = 20

    # Base query for BackgroundJob records
    jobs_query = BackgroundJob.all.includes(:ticket)

    # Apply status filter
    unless @filter_status == "all"
      jobs_query = jobs_query.where(status: @filter_status)
    end

    # Apply date filter
    case @filter_date
    when "today"
      jobs_query = jobs_query.where(created_at: { "$gte" => Date.current.beginning_of_day })
    when "week"
      jobs_query = jobs_query.where(created_at: { "$gte" => 1.week.ago })
    when "month"
      jobs_query = jobs_query.where(created_at: { "$gte" => 1.month.ago })
    end

    # Get paginated results - sort by most recent first
    @total_count = jobs_query.count
    @background_jobs = jobs_query
      .order_by(updated_at: :desc)
      .skip((@page - 1) * @per_page)
      .limit(@per_page)

    # Calculate statistics for dashboard
    @stats = calculate_job_statistics

    # Pagination info
    @total_pages = (@total_count.to_f / @per_page).ceil
    @has_next_page = @page < @total_pages
    @has_prev_page = @page > 1
  end

  def show
    # Show detailed information about a specific BackgroundJob
    @background_job = BackgroundJob.find(params[:id])
    @ticket = @background_job.ticket

    unless @background_job
      redirect_to admin_background_jobs_path, alert: "Background job not found."
      return
    end

    @page_title = "Job Details - #{@ticket.ticket_number}"

    # All debug information is now stored in the BackgroundJob model
    @processing_steps = @background_job.processing_steps || []
    @console_logs = @background_job.console_logs || []
    @retrieval_data = @background_job.rag_retrieval_data || []
  end

  def retry
    # Retry a failed AI analysis job
    @background_job = BackgroundJob.find(params[:id])
    @ticket = @background_job.ticket

    unless @background_job.failed?
      redirect_to admin_background_jobs_path, alert: "Job is not in failed state and cannot be retried."
      return
    end

    begin
      # Reset BackgroundJob status
      @background_job.update!(
        status: "queued",
        error_message: nil,
        error_class: nil,
        error_backtrace: nil,
        retry_count: 0
      )

      # Update AI analysis status as well
      if @ticket.ai_analysis
        @ticket.ai_analysis.update!(
          analysis_status: "queued",
          status_updated_at: Time.current,
          error_message: nil
        )
      end

      # Queue new job
      job = AiAnalysisJob.perform_later(@ticket.id)
      @background_job.update(activejob_id: job.job_id)

      # Log retry activity
      @ticket.activities.create!(
        performed_by: current_agent.display_name,
        action: "ai_analysis_retried",
        description: "AI analysis manually retried by #{current_agent.display_name}",
        performed_at: Time.current
      )

      @background_job.add_console_log("Manually retried by #{current_agent.display_name}", "INFO")

      redirect_to admin_background_jobs_path, notice: "✅ AI analysis job has been queued for retry."
    rescue => e
      Rails.logger.error "Failed to retry AI analysis for ticket #{@ticket.ticket_number}: #{e.message}"
      redirect_to admin_background_jobs_path, alert: "❌ Failed to retry job: #{e.message}"
    end
  end

  def clear_failed
    # Clear all failed jobs (mark them as dismissed)
    failed_count = BackgroundJob.where(status: "failed").count

    if failed_count > 0
      BackgroundJob.where(status: "failed").update_all(status: "dismissed")

      # Also update corresponding AI analysis records
      BackgroundJob.where(status: "dismissed").each do |job|
        if job.ticket&.ai_analysis
          job.ticket.ai_analysis.update(analysis_status: "dismissed")
        end
      end

      redirect_to admin_background_jobs_path, notice: "✅ Cleared #{failed_count} failed jobs."
    else
      redirect_to admin_background_jobs_path, alert: "No failed jobs to clear."
    end
  end

  private

  def ensure_admin
    unless current_agent&.admin?
      redirect_to tickets_path, alert: "❌ Access denied. Admin privileges required."
    end
  end

  def calculate_job_statistics
    # Calculate various statistics using BackgroundJob model
    total_jobs = BackgroundJob.count

    return {} if total_jobs == 0

    # Status counts using BackgroundJob model
    queued_count = BackgroundJob.where(status: "queued").count
    processing_count = BackgroundJob.where(status: "processing").count
    completed_count = BackgroundJob.where(status: "completed").count
    failed_count = BackgroundJob.where(status: "failed").count
    retrying_count = BackgroundJob.where(status: "retrying").count

    # Recent activity (last 24 hours)
    recent_jobs = BackgroundJob.where(created_at: { "$gte" => 1.day.ago }).count

    # Success rate calculation
    finished_jobs = completed_count + failed_count
    success_rate = finished_jobs > 0 ? ((completed_count.to_f / finished_jobs) * 100).round(1) : 0

    # Average processing time using BackgroundJob performance data
    avg_processing_time = BackgroundJob.average_duration("ai_analysis", 1.week)

    {
      total_jobs: total_jobs,
      queued: queued_count,
      processing: processing_count,
      completed: completed_count,
      failed: failed_count,
      retrying: retrying_count,
      recent_24h: recent_jobs,
      success_rate: success_rate,
      avg_processing_time_ms: avg_processing_time
    }
  end
end
