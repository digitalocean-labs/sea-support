class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # LEARNING NOTE: Global Authentication Filter
  # Require authentication for all controllers by default
  # Individual controllers can skip this with skip_before_action
  before_action :authenticate_agent!
  before_action :set_current_agent

  # LEARNING NOTE: Authentication Helpers
  # These methods provide session management for our MongoDB-based agents
  # Similar to Devise but custom-built for our specific needs

  private

  def current_agent
    # LEARNING NOTE: Memoization pattern (@current_agent ||=)
    # Only queries the database once per request, caches the result
    @current_agent ||= Agent.find(session[:agent_id]) if session[:agent_id]
  rescue Mongoid::Errors::DocumentNotFound
    # SECURITY: Clear invalid session if agent no longer exists
    session[:agent_id] = nil
    nil
  end

  # RAILS PATTERN: Make current_agent available in views
  helper_method :current_agent

  def agent_signed_in?
    current_agent.present?
  end
  helper_method :agent_signed_in?

  def authenticate_agent!
    # LEARNING NOTE: Redirect to login if not authenticated
    # This is used as a before_action filter in protected controllers
    unless agent_signed_in?
      store_location_for_redirect
      redirect_to login_path, alert: "Please sign in to continue."
    end
  end

  def require_admin!
    # AUTHORIZATION: Only admins can access certain features
    authenticate_agent!
    unless current_agent&.admin?
      redirect_to root_path, alert: "Access denied. Admin privileges required."
    end
  end

  def require_supervisor!
    # AUTHORIZATION: Supervisors and admins can access management features
    authenticate_agent!
    unless current_agent&.supervisor?
      redirect_to root_path, alert: "Access denied. Supervisor privileges required."
    end
  end

  def sign_in(agent)
    # LEARNING NOTE: Session-based authentication
    # Store agent ID in Rails session (encrypted cookie)
    session[:agent_id] = agent.id
    @current_agent = agent
  end

  def sign_out
    session[:agent_id] = nil
    @current_agent = nil
  end

  def store_location_for_redirect
    # LEARNING NOTE: Friendly redirects after login
    # Remember where user was trying to go, redirect there after login
    # DEFENSIVE PROGRAMMING: Only store location if we have a valid GET/HEAD request
    return unless defined?(request) && request.respond_to?(:request_method)

    begin
      # SECURITY: Only store location for safe HTTP methods (GET/HEAD)
      # HEAD requests are routed like GET but request.get? returns false
      if request.get? || request.head?
        session[:return_to] = request.original_url
      end
    rescue StandardError => e
      # LEARNING NOTE: Graceful degradation - log error but don't break the flow
      # This can happen in test environments or edge cases
      Rails.logger.warn "Failed to store location for redirect: #{e.message}"
    end
  end

  def redirect_back_or_default(default = root_path)
    redirect_to(session.delete(:return_to) || default)
  end

  def set_current_agent
    # LEARNING NOTE: Set Current.agent for request-scoped access
    # This allows any model or service to access the current agent
    Current.agent = current_agent
  end
end
