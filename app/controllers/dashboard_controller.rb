# LEARNING NOTE: Dashboard Controller
# Main application controller after login
# Shows agent dashboard with tickets, metrics, etc.

class DashboardController < ApplicationController
  # LEARNING NOTE: Require authentication for all dashboard actions
  before_action :authenticate_agent!

  def index
    # LEARNING NOTE: Dashboard Data Loading
    # Load relevant data for the authenticated agent

    @agent = current_agent
    @greeting = generate_coffee_greeting

    # Load recent tickets for dashboard display
    @recent_tickets = Ticket.desc(:created_at).limit(5)
    @pending_tickets_count = Ticket.where(status: [ "new", "open" ]).count
    @total_tickets_count = Ticket.count

    # MOODBREW FEATURE: Fun metrics for coffee theme
    @coffee_breaks_today = @agent.performance_metrics&.coffee_breaks_today || 0
    @tickets_resolved = @agent.performance_metrics&.tickets_resolved || 0
  end

  private

  def generate_coffee_greeting
    # MOODBREW FEATURE: Time-based coffee greetings
    hour = Time.current.hour

    case hour
    when 5..11
      "Good morning! ☀️ Time for that first cup of coffee and some great support!"
    when 12..17
      "Good afternoon! ☕ Hope you're staying caffeinated and helping customers!"
    when 18..21
      "Good evening! 🌅 Wrapping up another day of excellent support?"
    else
      "Working late? 🌙 Don't forget to take a coffee break!"
    end
  end
end
