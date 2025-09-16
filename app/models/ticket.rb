# app/models/ticket.rb
# LEARNING NOTE: MongoDB Document Model for Support Tickets
# This demonstrates MongoDB's document structure with embedded documents
# Unlike SQL, related data is stored together for better performance

# LEARNING NOTE: Embedded Document Classes
# These are stored as part of the Ticket document, not separate collections
# Define them first so they can be referenced in the main Ticket class

class CustomerInfo
  include Mongoid::Document
  
  embedded_in :ticket
  
  field :customer_name, type: String
  field :email, type: String
  field :phone, type: String
  field :account_tier, type: String, default: 'free' # free, premium, enterprise
  field :moodbrew_serial, type: String # Machine serial number
  field :purchase_date, type: Date
  field :warranty_status, type: String # active, expired, extended
  
  # LEARNING NOTE: Validations for embedded documents
  # Email is required and must be valid format
  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  # Customer name is optional - may not always have complete info
  # No validation needed - it can be blank
  validates :account_tier, inclusion: { in: %w[free premium enterprise] }
end

class AiAnalysis
  include Mongoid::Document
  
  embedded_in :ticket
  
  # CORE ANALYSIS RESULTS (keep for quick access)
  field :tags, type: Array, default: []
  field :summary, type: String
  field :sentiment, type: String # positive, neutral, negative, very_negative
  field :priority_suggestion, type: String
  field :suggested_response, type: String
  field :suggested_actions, type: Array, default: [] # AI-suggested next steps
  field :confidence_score, type: Float
  field :processed_at, type: DateTime
  field :processing_time_ms, type: Integer
  field :source_files, type: Array # Filenames/URLs of sources used (summary)
  
  # REFERENCE TO DETAILED JOB DATA
  field :background_job_id, type: BSON::ObjectId # Links to BackgroundJob for complete data
  
  # BACKGROUND JOB STATUS TRACKING (kept for compatibility)
  field :analysis_status, type: String, default: 'queued' # queued, processing, completed, failed, retrying
  field :status_updated_at, type: DateTime
  field :error_message, type: String # Error details for failed analyses
  field :job_id, type: String # ActiveJob job ID for tracking
  
  # LEARNING NOTE: Virtual attribute for checking freshness
  def stale?
    processed_at.nil? || processed_at < 1.hour.ago
  end
  
  def high_confidence?
    confidence_score && confidence_score >= 0.85
  end
  
  # Status checking methods for background job tracking
  def queued?
    analysis_status == 'queued'
  end
  
  def processing?
    analysis_status == 'processing'
  end
  
  def completed?
    analysis_status == 'completed'
  end
  
  def failed?
    analysis_status == 'failed'
  end
  
  def retrying?
    analysis_status == 'retrying'
  end
  
  def in_progress?
    queued? || processing? || retrying?
  end
  
  # ACCESS TO DETAILED JOB DATA
  def background_job
    @background_job ||= BackgroundJob.find(background_job_id) if background_job_id
  end
  
  def detailed_retrieval_data
    background_job&.rag_retrieval_data || []
  end
  
  def processing_steps
    background_job&.processing_steps || []
  end
  
  def console_logs
    background_job&.console_logs || []
  end
end

class TicketMessage
  include Mongoid::Document
  
  embedded_in :ticket
  
  field :sender, type: String # customer, agent, system
  field :sender_name, type: String
  field :content, type: String
  field :sent_at, type: DateTime
  field :is_ai_generated, type: Boolean, default: false
  field :ai_confidence, type: Float
  field :agent_approved, type: Boolean
  
  validates :sender, inclusion: { in: %w[customer agent system] }
  validates :content, presence: true
  
  # CLEAN CODE: Readable helper methods
  def from_customer?
    sender == 'customer'
  end
  
  def from_agent?
    sender == 'agent'
  end
  
  def ai_suggested?
    is_ai_generated && !agent_approved
  end
end

class TicketActivity
  include Mongoid::Document
  
  embedded_in :ticket
  
  field :action, type: String # created, assigned, updated, resolved, closed, etc.
  field :description, type: String
  field :performed_by, type: String
  field :performed_at, type: DateTime
  field :metadata, type: Hash # Additional context for the activity
  
  validates :action, presence: true
  validates :performed_at, presence: true
  
  # MONGODB TIP: Use default scopes sparingly, but they're useful for embedded docs
  default_scope -> { order(performed_at: :desc) }
end

class Ticket
  # LEARNING NOTE: Include Mongoid modules for MongoDB integration
  include Mongoid::Document
  include Mongoid::Timestamps # Adds created_at and updated_at automatically
  
  # LEARNING NOTE: Core Ticket Fields
  # In MongoDB, we define fields explicitly with their types
  field :ticket_number, type: String
  field :subject, type: String
  field :description, type: String
  field :status, type: String, default: 'new'
  field :priority, type: String, default: 'medium'
  field :channel, type: String, default: 'web' # web, email, chat, api
  
  # MOODBREW SPECIFIC: Coffee machine context
  field :machine_model, type: String # MoodBrew Pro, MoodBrew Home, etc.
  field :issue_category, type: String # brewing, maintenance, connectivity, mood-sensor
  field :customer_mood, type: String # angry, frustrated, happy, neutral
  
  # LEARNING NOTE: References to other collections
  # belongs_to creates a reference (like a foreign key in SQL)
  belongs_to :assigned_agent, class_name: 'Agent', optional: true
  belongs_to :created_by, class_name: 'Agent', optional: true # For internal tickets
  
  # BACKGROUND JOB TRACKING
  has_many :background_jobs, class_name: 'BackgroundJob', dependent: :destroy
  
  # LEARNING NOTE: Embedded Documents
  # These are stored within the ticket document, not in separate collections
  # This is MongoDB's denormalization pattern for better read performance
  embeds_one :customer_info, class_name: 'CustomerInfo'
  embeds_one :ai_analysis, class_name: 'AiAnalysis'
  embeds_many :messages, class_name: 'TicketMessage'
  embeds_many :activities, class_name: 'TicketActivity'
  
  # LEARNING NOTE: Nested Attributes for Forms
  # This allows Rails forms to create/update embedded documents
  accepts_nested_attributes_for :customer_info, allow_destroy: true
  
  # LEARNING NOTE: MongoDB Indexes for Query Performance
  # Unlike SQL, indexes must be explicitly defined in the model
  index({ ticket_number: 1 }, { unique: true, background: true })
  index({ status: 1, priority: -1 }) # Compound index for common queries
  index({ created_at: -1 }) # For sorting by newest
  index({ assigned_agent_id: 1 })
  index({ 'customer_info.email': 1 }) # Index on embedded document field
  
  # RAILS PATTERN: Validations work the same as ActiveRecord
  validates :subject, presence: true, length: { minimum: 5, maximum: 200 }
  validates :description, presence: true, length: { minimum: 10 }
  validates :status, inclusion: { in: %w[new open in_progress waiting_customer resolved closed] }
  validates :priority, inclusion: { in: %w[low medium high urgent] }
  validates :channel, inclusion: { in: %w[web email chat api phone] }
  
  # MOODBREW VALIDATIONS
  validates :issue_category, inclusion: { 
    in: %w[brewing maintenance connectivity mood-sensor billing other],
    allow_blank: true 
  }
  validates :machine_model, inclusion: {
    in: ['MoodBrew Pro', 'MoodBrew Home', 'MoodBrew Office', 'MoodBrew Cafe'],
    allow_blank: true
  }
  
  # LEARNING NOTE: Scopes for common queries (chainable)
  # MongoDB queries use a different syntax than SQL
  scope :open_tickets, -> { where(status: { '$in': ['new', 'open', 'in_progress'] }) }
  scope :closed_tickets, -> { where(status: { '$in': ['resolved', 'closed'] }) }
  scope :high_priority, -> { where(priority: { '$in': ['high', 'urgent'] }) }
  scope :unassigned, -> { where(assigned_agent_id: nil) }
  scope :recent, -> { order(created_at: :desc) }
  scope :by_category, ->(category) { where(issue_category: category) }
  
  # LEARNING NOTE: Callbacks for automatic processing
  before_create :generate_ticket_number
  after_create :create_initial_activity
  after_save :log_status_change, if: :saved_change_to_status?
  
  # BUSINESS LOGIC: Helper methods for ticket management
  
  def assign_to(agent)
    return false unless agent.is_a?(Agent)
    
    self.assigned_agent = agent
    log_activity('assigned', "Assigned to #{agent.display_name}")
    save
  end
  
  def resolve!(resolution_message = nil)
    self.status = 'resolved'
    log_activity('resolved', resolution_message || 'Ticket resolved')
    save
  end
  
  def reopen!(reason = nil)
    self.status = 'open'
    log_activity('reopened', reason || 'Ticket reopened')
    save
  end
  
  def add_message(sender, content)
    messages.create!(
      sender: sender,
      sender_name: sender == 'customer' ? customer_info&.customer_name : Current.agent&.display_name,
      content: content,
      sent_at: Time.current
    )
  end
  
  def escalated?
    priority == 'urgent' || (priority == 'high' && age_in_hours > 24)
  end
  
  def age_in_hours
    ((Time.current - created_at) / 1.hour).round
  end
  
  def sla_breach?
    case priority
    when 'urgent' then age_in_hours > 4
    when 'high' then age_in_hours > 24
    when 'medium' then age_in_hours > 72
    else false
    end
  end
  
  # AI INTEGRATION: Methods for AI processing
  
  def needs_ai_analysis?
    ai_analysis.nil? || ai_analysis.processed_at < 1.hour.ago
  end
  
  def apply_ai_suggestions(suggestions)
    return false unless suggestions.is_a?(Hash)
    
    # Update or create AI analysis
    if ai_analysis
      ai_analysis.update(suggestions)
    else
      create_ai_analysis(suggestions)
    end
    
    # Auto-apply high confidence suggestions
    if suggestions[:confidence_score] && suggestions[:confidence_score] > 0.85
      self.priority = suggestions[:priority_suggestion] if suggestions[:priority_suggestion]
      save
    end
  end
  
  private
  
  def generate_ticket_number
    # BEST PRACTICE: Human-readable ticket numbers
    # Format: TKT-YYYYMMDD-XXXXXX (e.g., TKT-20240115-A3F2B1)
    date_part = Time.current.strftime('%Y%m%d')
    random_part = SecureRandom.hex(3).upcase
    self.ticket_number = "TKT-#{date_part}-#{random_part}"
  end
  
  def create_initial_activity
    activities.create!(
      action: 'created',
      description: 'Ticket created',
      performed_by: created_by&.display_name || customer_info&.customer_name || 'System',
      performed_at: Time.current
    )
  end
  
  def log_activity(action, description)
    activities.create!(
      action: action,
      description: description,
      performed_by: Current.agent&.display_name || 'System',
      performed_at: Time.current
    )
  end
  
  def log_status_change
    return if saved_change_to_status.nil? # No status change
    return if saved_change_to_status[0].nil? # Initial status setting on create
    
    old_status, new_status = saved_change_to_status
    log_activity('status_changed', "Status changed from #{old_status} to #{new_status}")
  end
end