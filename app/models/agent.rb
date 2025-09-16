# app/models/agent.rb
# LEARNING NOTE: MongoDB Models with Mongoid
# This is how you create a model for MongoDB using Mongoid
# Compare to ActiveRecord: class User < ApplicationRecord

class Agent
  # LEARNING NOTE: Include Mongoid modules instead of inheriting
  # This is the key difference between Mongoid and ActiveRecord
  include Mongoid::Document
  include Mongoid::Timestamps # Adds created_at and updated_at fields
  
  # LEARNING NOTE: ActiveModel integration with Mongoid
  # We need ActiveModel::SecurePassword for has_secure_password to work with MongoDB
  include ActiveModel::SecurePassword
  
  # LEARNING NOTE: Field Definitions in MongoDB
  # Unlike ActiveRecord, we explicitly define all fields and their types
  # MongoDB is schemaless, but Mongoid adds structure for Rails conventions
  
  field :email, type: String
  field :name, type: String
  field :password_digest, type: String # For has_secure_password
  field :role, type: String, default: 'agent'
  
  # LEARNING NOTE: Embedded Documents for Complex Data
  # Instead of separate tables/JOINs, we embed related data directly
  # This is a key MongoDB pattern - denormalization for performance
  embeds_one :preferences, class_name: 'AgentPreferences'
  embeds_one :performance_metrics, class_name: 'AgentPerformanceMetrics'
  
  # LEARNING NOTE: MongoDB Indexes
  # Must be explicitly defined (unlike SQL where they're in migrations)
  # These improve query performance significantly
  index({ email: 1 }, { unique: true, background: true })
  index({ role: 1 })
  index({ created_at: -1 }) # -1 means descending order
  
  # RAILS PATTERN: Validations (work exactly like ActiveRecord)
  validates :email, presence: true, uniqueness: true
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :name, presence: true
  validates :role, inclusion: { in: %w[agent supervisor admin] }
  
  # LEARNING NOTE: has_secure_password with MongoDB
  # Works the same as ActiveRecord - requires bcrypt gem
  # Provides authenticate method and password= setter
  # validations: false allows us to customize password validation messages
  has_secure_password validations: false
  
  # LEARNING NOTE: Custom password validations
  # More user-friendly error messages than the default has_secure_password ones
  validates :password, presence: true, length: { minimum: 8 }, on: :create
  validates :password, length: { minimum: 8 }, allow_blank: true, on: :update
  validates :password_confirmation, presence: true, on: :create
  validate :password_confirmation_matches, on: :create
  
  # CLEAN CODE: Use scopes for commonly used queries
  scope :agents, -> { where(role: 'agent') }
  scope :supervisors, -> { where(role: 'supervisor') }
  scope :recent, -> { order(created_at: :desc) }
  
  # LEARNING NOTE: Virtual Attributes (computed fields)
  # These don't get stored in MongoDB but are calculated on demand
  def display_name
    name.presence || email.split('@').first.titleize
  end
  
  def admin?
    role == 'admin'
  end
  
  def supervisor?
    role == 'supervisor' || admin?
  end
  
  # LEARNING NOTE: Callbacks work the same as ActiveRecord
  before_save :normalize_email
  after_create :initialize_metrics
  
  private
  
  def password_confirmation_matches
    return unless password.present? && password_confirmation.present?
    
    if password != password_confirmation
      errors.add(:password_confirmation, "doesn't match Password")
    end
  end
  
  def normalize_email
    # BEST PRACTICE: Normalize email addresses
    self.email = email.downcase.strip if email
  end
  
  def initialize_metrics
    # MONGODB PATTERN: Create embedded documents when parent is created
    create_performance_metrics unless performance_metrics
    create_preferences unless preferences
  end
end

# LEARNING NOTE: Embedded Document Classes
# These are stored as part of the Agent document, not separate collections
# This is more efficient than SQL JOINs for frequently accessed data

class AgentPreferences
  include Mongoid::Document
  
  # LEARNING NOTE: embedded_in defines the parent relationship
  embedded_in :agent
  
  field :auto_assign_enabled, type: Boolean, default: true
  field :email_notifications, type: Boolean, default: true
  field :sound_alerts, type: Boolean, default: false
  field :theme, type: String, default: 'coffee' # MoodBrew theme!
end

class AgentPerformanceMetrics
  include Mongoid::Document
  
  embedded_in :agent
  
  field :tickets_resolved, type: Integer, default: 0
  field :avg_resolution_time_minutes, type: Float, default: 0.0
  field :ai_approval_rate, type: Float, default: 0.0 # Percentage of AI suggestions accepted
  field :customer_satisfaction_score, type: Float, default: 0.0
  field :coffee_breaks_today, type: Integer, default: 0 # MoodBrew fun metric!
end