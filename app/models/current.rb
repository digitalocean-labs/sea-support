# app/models/current.rb
# LEARNING NOTE: CurrentAttributes for Request-Scoped Data
# Rails provides CurrentAttributes for storing request-specific data
# This is useful for tracking the current user across the application

class Current < ActiveSupport::CurrentAttributes
  # LEARNING NOTE: These attributes are reset for each request
  # Perfect for storing the logged-in agent without passing it everywhere
  attribute :agent
  
  # Helper method to check if an agent is logged in
  def agent_signed_in?
    agent.present?
  end
end