class Api::V1::BaseController < ApplicationController
  include ActionController::API
  
  before_action :authenticate_api_key
  before_action :check_rate_limit
  before_action :log_api_request
  after_action :log_api_response
  
  rescue_from StandardError, with: :handle_api_error
  rescue_from Mongoid::Errors::DocumentNotFound, with: :handle_not_found
  rescue_from Mongoid::Errors::Validations, with: :handle_validation_error

  private

  def authenticate_api_key
    api_key = request.headers['X-API-Key'] || params[:api_key]
    
    unless api_key && valid_api_key?(api_key)
      render_error('Invalid or missing API key', :unauthorized)
      return false
    end

    @current_api_client = find_api_client(api_key)
  end

  def check_rate_limit
    return true unless @current_api_client

    rate_limiter = RateLimiter.new(@current_api_client)
    
    unless rate_limiter.allow_request?
      render_error(
        'Rate limit exceeded. Try again later.',
        :too_many_requests,
        {
          retry_after: rate_limiter.retry_after,
          limit: rate_limiter.limit,
          remaining: rate_limiter.remaining
        }
      )
      return false
    end

    # Add rate limit headers
    response.headers['X-RateLimit-Limit'] = rate_limiter.limit.to_s
    response.headers['X-RateLimit-Remaining'] = rate_limiter.remaining.to_s
    response.headers['X-RateLimit-Reset'] = rate_limiter.reset_time.to_s
  end

  def log_api_request
    @request_start_time = Time.current
    
    Rails.logger.info "[API] #{request.method} #{request.path} - Client: #{@current_api_client&.name}"
  end

  def log_api_response
    duration = (Time.current - @request_start_time) * 1000
    
    Rails.logger.info "[API] Response: #{response.status} - Duration: #{duration.round(2)}ms"
    
    # Store metrics for monitoring
    ApiMetric.create!(
      client_id: @current_api_client&.id,
      endpoint: "#{request.method} #{request.path}",
      status_code: response.status,
      response_time_ms: duration.round(2),
      timestamp: Time.current
    )
  end

  def render_success(data = {}, status = :ok, meta = {})
    response_data = {
      success: true,
      data: data,
      meta: {
        timestamp: Time.current.iso8601,
        request_id: request.uuid
      }.merge(meta)
    }

    render json: response_data, status: status
  end

  def render_error(message, status = :bad_request, details = {})
    error_data = {
      success: false,
      error: {
        message: message,
        code: status.to_s.upcase,
        details: details,
        timestamp: Time.current.iso8601,
        request_id: request.uuid
      }
    }

    render json: error_data, status: status
  end

  def handle_api_error(exception)
    Rails.logger.error "[API ERROR] #{exception.class}: #{exception.message}"
    Rails.logger.error exception.backtrace.join("\n")

    render_error(
      'Internal server error',
      :internal_server_error,
      { type: exception.class.name }
    )
  end

  def handle_not_found(exception)
    render_error('Resource not found', :not_found)
  end

  def handle_validation_error(exception)
    render_error(
      'Validation failed',
      :unprocessable_entity,
      { errors: exception.document.errors.full_messages }
    )
  end

  def valid_api_key?(key)
    ApiClient.where(api_key: key, active: true).exists?
  end

  def find_api_client(key)
    ApiClient.find_by(api_key: key)
  end

  def paginate(collection, page: 1, per_page: 20)
    page = [page.to_i, 1].max
    per_page = [[per_page.to_i, 1].max, 100].min # Max 100 per page

    offset = (page - 1) * per_page
    total_count = collection.count

    {
      items: collection.skip(offset).limit(per_page),
      pagination: {
        current_page: page,
        per_page: per_page,
        total_count: total_count,
        total_pages: (total_count.to_f / per_page).ceil,
        has_next: page * per_page < total_count,
        has_prev: page > 1
      }
    }
  end
end

# API Client model for authentication and rate limiting
class ApiClient
  include Mongoid::Document
  include Mongoid::Timestamps

  field :name, type: String
  field :api_key, type: String
  field :active, type: Boolean, default: true
  field :rate_limit, type: Integer, default: 1000 # requests per hour
  field :allowed_endpoints, type: Array, default: []
  field :last_used_at, type: Time

  validates :name, presence: true
  validates :api_key, presence: true, uniqueness: true

  before_create :generate_api_key

  index({ api_key: 1 }, { unique: true })
  index({ active: 1 })

  private

  def generate_api_key
    self.api_key = SecureRandom.hex(32) if api_key.blank?
  end
end

# Rate limiter service
class RateLimiter
  WINDOW_SIZE = 1.hour

  def initialize(api_client)
    @api_client = api_client
    @cache_key = "rate_limit:#{api_client.id}"
  end

  def allow_request?
    current_count = get_current_count
    current_count < @api_client.rate_limit
  end

  def remaining
    [@api_client.rate_limit - get_current_count, 0].max
  end

  def limit
    @api_client.rate_limit
  end

  def retry_after
    window_start = Time.current.beginning_of_hour
    (window_start + WINDOW_SIZE).to_i
  end

  def reset_time
    Time.current.beginning_of_hour + WINDOW_SIZE
  end

  private

  def get_current_count
    window_start = Time.current.beginning_of_hour
    
    # Get current count and increment
    current_count = Rails.cache.read(@cache_key) || 0
    Rails.cache.write(@cache_key, current_count + 1, expires_at: window_start + WINDOW_SIZE)
    
    current_count
  end
end

# API metrics model
class ApiMetric
  include Mongoid::Document

  field :client_id, type: String
  field :endpoint, type: String
  field :status_code, type: Integer
  field :response_time_ms, type: Float
  field :timestamp, type: Time

  index({ client_id: 1, timestamp: -1 })
  index({ endpoint: 1, timestamp: -1 })
  index({ timestamp: -1 })

  # Auto-cleanup old metrics (keep 30 days)
  scope :recent, -> { where(timestamp: 30.days.ago..Time.current) }
end
