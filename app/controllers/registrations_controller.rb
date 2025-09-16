# LEARNING NOTE: Registrations Controller
# Handles agent signup functionality
# In a real app, you might restrict this to admin-only or require invitation codes

class RegistrationsController < ApplicationController
  # LEARNING NOTE: Skip authentication for signup pages
  skip_before_action :authenticate_agent!, only: [:new, :create]
  
  def new
    # LEARNING NOTE: Redirect if already logged in
    if agent_signed_in?
      redirect_to root_path, notice: "Already signed in as #{current_agent.display_name}"
      return
    end
    
    @agent = Agent.new
  end
  
  def create
    # LEARNING NOTE: Registration Flow
    # 1. Create new agent with form parameters
    # 2. If valid, sign them in and redirect
    # 3. If invalid, show errors and re-render form
    
    @agent = Agent.new(registration_params)
    
    if @agent.save
      # SUCCESS: Sign in the new agent
      sign_in(@agent)
      
      # MOODBREW FEATURE: Welcome message for new agents
      welcome_message = "Welcome to MoodBrew Support, #{@agent.display_name}! ☕ " \
                       "Your account has been created. Let's start brewing amazing customer experiences!"
      
      redirect_to dashboard_path, notice: welcome_message
    else
      # FAILURE: Show validation errors
      flash.now[:alert] = 'Please fix the errors below.'
      render :new, status: :unprocessable_content
    end
  end
  
  private
  
  def registration_params
    # LEARNING NOTE: Strong Parameters for Registration
    # Allow name, email, password, and password_confirmation
    # Role defaults to 'agent' in the model
    params.require(:agent).permit(:name, :email, :password, :password_confirmation)
  end
end