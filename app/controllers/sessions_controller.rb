# LEARNING NOTE: Sessions Controller
# Handles login and logout functionality for agents
# This is the equivalent of Devise's sessions controller but custom-built

class SessionsController < ApplicationController
  # LEARNING NOTE: Skip authentication for login/logout pages
  # These pages need to be accessible to non-authenticated users
  skip_before_action :authenticate_agent!, only: [:new, :create, :destroy]
  skip_before_action :set_current_agent, only: [:new, :create, :destroy]
  
  def new
    # LEARNING NOTE: Redirect if already logged in
    # Prevents authenticated users from seeing login page
    if agent_signed_in?
      redirect_to dashboard_path, notice: "Already signed in as #{current_agent.display_name}"
      return
    end
    
    # LEARNING NOTE: Create empty agent for form binding
    # This helps with form validation and error display
    @agent = Agent.new
  end
  
  def create
    # LEARNING NOTE: Authentication Flow
    # 1. Find agent by email
    # 2. Verify password using has_secure_password
    # 3. Create session if valid, show error if not
    
    @agent = Agent.where(email: session_params[:email].downcase.strip).first
    
    if @agent&.authenticate(session_params[:password])
      # SUCCESS: Create session and redirect
      sign_in(@agent)
      
      # MOODBREW FEATURE: Welcome message with coffee theme
      welcome_message = "Welcome back, #{@agent.display_name}! ☕ Ready to brew some great support?"
      
      flash[:notice] = welcome_message
      redirect_back_or_default(dashboard_path)
    else
      # FAILURE: Show error and re-render login form
      @agent = Agent.new(email: session_params[:email]) # Keep email for form
      flash.now[:alert] = 'Invalid email or password. Please try again.'
      render :new, status: :unprocessable_content
    end
  end
  
  def destroy
    # LEARNING NOTE: Logout Flow
    # Clear session and redirect with confirmation
    
    agent_name = current_agent&.display_name || 'Agent'
    sign_out
    
    # MOODBREW FEATURE: Friendly logout message
    redirect_to login_path, notice: "Goodbye, #{agent_name}! Thanks for brewing great support today! ☕"
  end
  
  private
  
  def session_params
    # LEARNING NOTE: Strong Parameters
    # Only allow email and password for security
    params.require(:agent).permit(:email, :password)
  end
end