# app/models/background_job.rb
# LEARNING NOTE: MongoDB Model for Complete AI Analysis Job Tracking
# This replaces temporary Redis cache with permanent MongoDB storage
# Stores complete AI request/response cycles, debug data, and performance metrics

class BackgroundJob
  include Mongoid::Document
  include Mongoid::Timestamps

  # CORE JOB IDENTIFICATION
  field :ticket_id, type: BSON::ObjectId
  field :job_type, type: String # 'ai_analysis', 'response_generation', 'bulk_analysis'
  field :status, type: String, default: "queued" # 'queued', 'processing', 'completed', 'failed', 'retrying'

  # AI SYSTEM TRACKING
  field :ai_endpoint, type: String # 'agent', 'gradient'
  field :ai_model, type: String # Track which AI model was used
  field :activejob_id, type: String # Rails ActiveJob ID for correlation

  # COMPLETE REQUEST/RESPONSE STORAGE
  field :request_json, type: Hash # Full request sent to AI API
  field :response_json, type: Hash # Complete AI response received
  field :rag_retrieval_data, type: Array # RAG documents retrieved with scores

  # DEBUG AND PROCESSING DATA
  field :processing_steps, type: Array # All debug steps with timestamps
  field :console_logs, type: Array # Complete console log history
  field :debug_session_data, type: Hash # Additional debug information

  # PERFORMANCE METRICS
  field :total_duration_ms, type: Integer # End-to-end processing time
  field :ai_call_duration_ms, type: Integer # AI API call duration
  field :parsing_duration_ms, type: Integer # Response parsing time
  field :response_generation_duration_ms, type: Integer # Customer response generation time

  # ERROR TRACKING
  field :error_message, type: String
  field :error_class, type: String
  field :error_backtrace, type: Array
  field :retry_count, type: Integer, default: 0
  field :max_retries, type: Integer, default: 3

  # ANALYSIS RESULTS SUMMARY (for quick access)
  field :confidence_score, type: Float
  field :suggested_priority, type: String
  field :sentiment_detected, type: String
  field :tags_generated, type: Array
  field :has_suggested_response, type: Boolean, default: false

  # RELATIONSHIPS
  belongs_to :ticket

  # VALIDATIONS
  validates :job_type, inclusion: { in: %w[ai_analysis response_generation bulk_analysis] }
  validates :status, inclusion: { in: %w[queued processing completed failed retrying dismissed] }
  validates :ai_endpoint, inclusion: { in: %w[agent gradient], allow_nil: true }

  # MONGODB INDEXES for Query Performance
  index({ ticket_id: 1, created_at: -1 }) # Query jobs for specific ticket
  index({ status: 1, job_type: 1 }) # Filter by status and type
  index({ created_at: -1 }) # Sort by most recent
  index({ ai_endpoint: 1, status: 1 }) # Performance analysis by endpoint
  index({ confidence_score: -1 }, { sparse: true }) # High confidence jobs
  index({ activejob_id: 1 }, { unique: true, sparse: true }) # ActiveJob correlation

  # SCOPES for Common Queries
  scope :recent, -> { order(created_at: :desc) }
  scope :for_ticket, ->(ticket_id) { where(ticket_id: ticket_id) }
  scope :by_status, ->(status) { where(status: status) }
  scope :ai_analysis_jobs, -> { where(job_type: "ai_analysis") }
  scope :high_confidence, -> { where(:confidence_score.gte => 0.85) }
  scope :with_errors, -> { where(:error_message.exists => true) }
  scope :completed_successfully, -> { where(status: "completed", :error_message.exists => false) }

  # STATUS CHECKING METHODS
  def queued?
    status == "queued"
  end

  def processing?
    status == "processing"
  end

  def completed?
    status == "completed"
  end

  def failed?
    status == "failed"
  end

  def retrying?
    status == "retrying"
  end

  def in_progress?
    queued? || processing? || retrying?
  end

  def can_retry?
    failed? && retry_count < max_retries
  end

  # PERFORMANCE HELPER METHODS
  def total_duration_seconds
    total_duration_ms ? (total_duration_ms / 1000.0).round(2) : nil
  end

  def ai_call_duration_seconds
    ai_call_duration_ms ? (ai_call_duration_ms / 1000.0).round(2) : nil
  end

  def high_confidence?
    confidence_score && confidence_score >= 0.85
  end

  def has_retrieval_data?
    rag_retrieval_data.present? && rag_retrieval_data.any?
  end

  # DATA EXTRACTION HELPERS
  def source_files
    return [] unless has_retrieval_data?

    rag_retrieval_data.map { |item| item["filename"] }.compact.uniq
  end

  def retrieval_sources_summary
    return "No sources" unless has_retrieval_data?

    sources = source_files
    if sources.length <= 3
      sources.join(", ")
    else
      "#{sources.first(2).join(', ')} and #{sources.length - 2} more"
    end
  end

  # DEBUG DATA ACCESS
  def latest_step
    processing_steps&.last
  end

  def step_by_name(step_name)
    processing_steps&.find { |step| step["name"] == step_name }
  end

  def error_summary
    return nil unless failed?

    "#{error_class}: #{error_message&.truncate(100)}"
  end

  # LOGGING HELPERS
  def add_processing_step(name, description, status = "in_progress", duration_ms = nil)
    step_data = {
      name: name,
      description: description,
      status: status.to_s,
      timestamp: Time.current,
      duration_ms: duration_ms
    }

    # Update existing step or add new one
    self.processing_steps ||= []
    existing_index = processing_steps.find_index { |s| s["name"] == name }

    if existing_index
      processing_steps[existing_index].merge!(step_data)
    else
      processing_steps << step_data
    end

    # Save immediately for real-time tracking
    save if persisted?
  end

  def add_console_log(message, level = "DEBUG")
    log_entry = {
      timestamp: Time.current,
      level: level,
      message: message
    }

    self.console_logs ||= []
    console_logs << log_entry

    # Keep only last 100 log entries to prevent document bloat
    self.console_logs = console_logs.last(100)

    # Save if already persisted
    save if persisted?
  end

  def mark_completed(final_data = {})
    self.status = "completed"

    # Update final metrics if provided
    final_data.each do |key, value|
      send("#{key}=", value) if respond_to?("#{key}=")
    end

    save
  end

  def mark_failed(error_obj, retry_count = 0)
    self.status = retry_count < max_retries ? "retrying" : "failed"
    self.error_message = error_obj.message
    self.error_class = error_obj.class.name
    self.error_backtrace = error_obj.backtrace&.first(20) # Limit backtrace size
    self.retry_count = retry_count

    save
  end

  # CLASS METHODS for Statistics
  def self.success_rate(time_period = 1.week)
    jobs = where(created_at: { "$gte" => time_period.ago })
    return 0 if jobs.count == 0

    successful = jobs.where(status: "completed", :error_message.exists => false).count
    (successful.to_f / jobs.count * 100).round(1)
  end

  def self.average_duration(job_type = nil, time_period = 1.week)
    query = where(
      status: "completed",
      created_at: { "$gte" => time_period.ago },
      :total_duration_ms.exists => true
    )

    query = query.where(job_type: job_type) if job_type

    durations = query.pluck(:total_duration_ms)
    return 0 if durations.empty?

    (durations.sum / durations.count.to_f).round
  end

  def self.top_error_types(limit = 5, time_period = 1.week)
    where(
      status: "failed",
      created_at: { "$gte" => time_period.ago },
      :error_class.exists => true
    ).group_by(&:error_class)
     .transform_values(&:count)
     .sort_by { |_, count| -count }
     .first(limit)
  end
end
