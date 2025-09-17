# db/seeds.rb
# LEARNING NOTE: Database Seeding for MoodBrew Support System
# This file populates the MongoDB database with realistic support content
# Run with: rails db:seed

puts "🌱 Seeding MoodBrew Support Database..."

# Clear existing data in development
if Rails.env.development?
  puts "  🧹 Cleaning existing data..."
  ticket_count = Ticket.count
  bg_job_count = BackgroundJob.count
  agent_count = Agent.where(:email.ne => 'admin@moodbrew.com').count

  Ticket.destroy_all
  BackgroundJob.destroy_all # Explicitly clear all background job records
  Agent.where(:email.ne => 'admin@moodbrew.com').destroy_all # Keep admin if exists

  puts "    ✅ Cleared #{ticket_count} tickets"
  puts "    ✅ Cleared #{bg_job_count} background jobs"
  puts "    ✅ Cleared #{agent_count} agents (keeping admin)"
end

# LEARNING NOTE: Create Admin Agent First
puts "  👤 Creating support agents..."

admin = Agent.find_or_create_by!(email: 'admin@moodbrew.com') do |agent|
  agent.name = 'Alex Admin'
  agent.password = 'password123'
  agent.password_confirmation = 'password123'
  agent.role = 'admin'
end

supervisor = Agent.create!(
  name: 'Sarah Supervisor',
  email: 'sarah@moodbrew.com',
  password: 'password123',
  password_confirmation: 'password123',
  role: 'supervisor'
)

agent1 = Agent.create!(
  name: 'Mike Coffee',
  email: 'mike@moodbrew.com',
  password: 'password123',
  password_confirmation: 'password123',
  role: 'agent'
)

agent2 = Agent.create!(
  name: 'Emma Brew',
  email: 'emma@moodbrew.com',
  password: 'password123',
  password_confirmation: 'password123',
  role: 'agent'
)

puts "    ✅ Created #{Agent.count} agents"

# SAMPLE TICKETS
puts "  🎫 Creating sample support tickets..."

# High Priority Ticket - Created during morning rush
ticket1 = Ticket.create!(
  subject: "MoodBrew Pro completely stopped working after power outage",
  description: "Hi, my MoodBrew Pro was working fine until we had a power outage yesterday. Now when I turn it on, the display shows error code E-07 and it won't brew anything. I tried unplugging it and plugging it back in, but same issue. This is really frustrating because I rely on my morning coffee and have an important presentation today. Please help ASAP!",
  status: 'new',
  priority: 'urgent',
  channel: 'chat',
  machine_model: 'MoodBrew Pro',
  issue_category: 'brewing',
  customer_mood: 'frustrated',
  assigned_agent: agent1,
  created_by: nil,
  created_at: 8.hours.ago,
  updated_at: 8.hours.ago
)

# Add customer info
ticket1.create_customer_info(
  customer_name: 'Jennifer Martinez',
  email: 'j.martinez@techcorp.com',
  phone: '+1-555-0123',
  account_tier: 'premium',
  moodbrew_serial: 'MBP-2024-789456',
  purchase_date: 3.months.ago,
  warranty_status: 'active'
)

# Add initial message
ticket1.messages.create!(
  sender: 'customer',
  sender_name: 'Jennifer Martinez',
  content: ticket1.description,
  sent_at: 8.hours.ago
)

# Medium Priority Ticket - Mid-day email
ticket2 = Ticket.create!(
  subject: "Mood sensor seems inaccurate - always suggests same coffee",
  description: "I've been using my MoodBrew Home for about 6 months and lately the mood sensor keeps suggesting the same coffee blend regardless of how I'm feeling. I've tried recalibrating it following the app instructions, but it's still not working right. It used to be pretty accurate at detecting when I was tired vs energetic, but now it just defaults to medium strength every time.",
  status: 'open',
  priority: 'medium',
  channel: 'email',
  machine_model: 'MoodBrew Home',
  issue_category: 'mood-sensor',
  customer_mood: 'neutral',
  assigned_agent: agent2,
  created_at: 1.day.ago,
  updated_at: 4.hours.ago
)

ticket2.create_customer_info(
  customer_name: 'David Chen',
  email: 'david.chen.home@gmail.com',
  phone: '+1-555-0456',
  account_tier: 'free',
  moodbrew_serial: 'MBH-2024-123789',
  purchase_date: 6.months.ago,
  warranty_status: 'active'
)

# Add initial message for ticket2
ticket2.messages.create!(
  sender: 'customer',
  sender_name: 'David Chen',
  content: ticket2.description,
  sent_at: 1.day.ago
)

# Low Priority Ticket - Recent web inquiry
ticket3 = Ticket.create!(
  subject: "Question about descaling frequency",
  description: "Hi there! I just got my new MoodBrew Office last week and I'm loving it so far. I was reading through the manual and have a question about the descaling schedule. We have pretty hard water in our office building - should I descale more frequently than the recommended monthly interval? Also, can I use regular white vinegar or do I need to buy the special MoodBrew descaling solution? Thanks!",
  status: 'new',
  priority: 'low',
  channel: 'web',
  machine_model: 'MoodBrew Office',
  issue_category: 'maintenance',
  customer_mood: 'happy',
  created_at: 2.days.ago,
  updated_at: 2.days.ago
)

ticket3.create_customer_info(
  customer_name: 'Rachel Thompson',
  email: 'rachel@creativestudio.com',
  phone: '+1-555-0789',
  account_tier: 'enterprise',
  moodbrew_serial: 'MBO-2024-456123',
  purchase_date: 1.week.ago,
  warranty_status: 'active'
)

# Add initial message for ticket3
ticket3.messages.create!(
  sender: 'customer',
  sender_name: 'Rachel Thompson',
  content: ticket3.description,
  sent_at: 2.days.ago
)

# Resolved Ticket - Phone support success
ticket4 = Ticket.create!(
  subject: "WiFi connection keeps dropping",
  description: "My MoodBrew Pro keeps losing its WiFi connection. I'll connect it through the app and it works for a few days, then suddenly I can't control it remotely anymore. The WiFi light goes from solid blue to flashing blue. I've restarted my router and the machine multiple times. Any ideas?",
  status: 'resolved',
  priority: 'medium',
  channel: 'phone',
  machine_model: 'MoodBrew Pro',
  issue_category: 'connectivity',
  customer_mood: 'frustrated',
  assigned_agent: supervisor,
  created_at: 5.days.ago,
  updated_at: 2.days.ago
)

ticket4.create_customer_info(
  customer_name: 'Michael Rodriguez',
  email: 'mike.rod@homeoffice.net',
  phone: '+1-555-0321',
  account_tier: 'premium',
  moodbrew_serial: 'MBP-2024-987654',
  purchase_date: 4.months.ago,
  warranty_status: 'active'
)

# Keep all tickets without AI analysis for fresh demo state

# Add conversation messages
ticket4.messages.create!(
  sender: 'customer',
  sender_name: 'Michael Rodriguez',
  content: ticket4.description,
  sent_at: 5.days.ago
)

ticket4.messages.create!(
  sender: 'agent',
  sender_name: supervisor.display_name,
  content: "Hi Michael, I understand how frustrating intermittent connectivity can be. Let's troubleshoot this step by step. First, can you check if your router broadcasts both 2.4GHz and 5GHz networks? MoodBrew only connects to 2.4GHz, so if they're combined into one network name, that might cause issues.",
  sent_at: 4.days.ago
)

ticket4.messages.create!(
  sender: 'customer',
  sender_name: 'Michael Rodriguez',
  content: "Thanks for the quick response! I checked and my router does have both bands combined. I separated them and reconnected the MoodBrew to the 2.4GHz network specifically. So far so good - it's been connected for 2 days now.",
  sent_at: 3.days.ago
)

ticket4.messages.create!(
  sender: 'agent',
  sender_name: supervisor.display_name,
  content: "Excellent! That's exactly what I hoped would fix it. The separate 2.4GHz network gives the MoodBrew a more stable connection. Please let us know if you experience any other issues, but this should resolve the dropping connection problem permanently.",
  sent_at: 2.days.ago,
  is_ai_generated: false
)

# Create more varied tickets with realistic customers
more_tickets = [
  {
    subject: "Strange noise during brewing cycle",
    description: "My MoodBrew Home has started making a loud grinding noise during the brewing process. It still makes coffee but the noise is quite loud and concerning. Is this normal?",
    priority: 'medium',
    issue_category: 'maintenance',
    customer_mood: 'concerned',
    customer_name: 'Sarah Williams',
    email: 'sarah.williams@gmail.com',
    phone: '+1-555-0654',
    account_tier: 'free',
    serial: 'MBH-2024-654321',
    purchase_date: 4.months.ago,
    created_at: 2.days.ago
  },
  {
    subject: "Love my MoodBrew! Feature request",
    description: "I absolutely love my MoodBrew Pro! The mood detection is amazing. I was wondering if you could add a feature to schedule different mood profiles for different times of day? Like energetic coffee at 7am but calm coffee at 9pm?",
    priority: 'low',
    issue_category: 'other',
    customer_mood: 'happy',
    customer_name: 'James Patterson',
    email: 'j.patterson@techstartup.io',
    phone: '+1-555-0987',
    account_tier: 'premium',
    serial: 'MBP-2024-111222',
    purchase_date: 2.months.ago,
    created_at: 1.day.ago
  },
  {
    subject: "Coffee tastes burnt - temperature too high?",
    description: "The coffee from my MoodBrew Office has been tasting burnt lately, even with medium roast beans. I think the water might be too hot. How can I adjust the brewing temperature?",
    priority: 'medium',
    issue_category: 'brewing',
    customer_mood: 'neutral',
    customer_name: 'Maria Garcia',
    email: 'mgarcia@lawfirm.com',
    phone: '+1-555-0432',
    account_tier: 'enterprise',
    serial: 'MBO-2024-333444',
    purchase_date: 5.months.ago,
    created_at: 4.hours.ago
  },
  {
    subject: "App won't connect to my MoodBrew Pro",
    description: "I'm having trouble connecting the MoodBrew app to my machine. The WiFi setup worked fine initially, but now the app says 'device not found' whenever I try to connect. The machine is connected to WiFi (blue light is solid), but the app won't see it. I've tried restarting both the app and the machine.",
    priority: 'high',
    issue_category: 'connectivity',
    customer_mood: 'frustrated',
    customer_name: 'Alex Kumar',
    email: 'alex.kumar.dev@gmail.com',
    phone: '+1-555-0198',
    account_tier: 'premium',
    serial: 'MBP-2024-555666',
    purchase_date: 1.month.ago,
    created_at: 6.hours.ago
  },
  {
    subject: "Descaling question for hard water area",
    description: "We just moved to an area with very hard water and I want to make sure I'm taking proper care of my MoodBrew Cafe. Should I be descaling more frequently? Also, I noticed some white buildup around the water spout - is this normal? The machine is still under warranty.",
    priority: 'low',
    issue_category: 'maintenance',
    customer_mood: 'neutral',
    customer_name: 'Lisa Chen',
    email: 'lisa.chen@consulting.biz',
    phone: '+1-555-0765',
    account_tier: 'enterprise',
    serial: 'MBC-2024-777888',
    purchase_date: 8.months.ago,
    created_at: 3.days.ago
  },
  {
    subject: "Mood sensor won't calibrate after factory reset",
    description: "Hi! I had to do a factory reset on my MoodBrew Pro due to some WiFi issues (which are now resolved). However, I can't seem to get the mood sensor to calibrate properly. I've followed the app instructions multiple times, but it keeps saying 'calibration failed'. The sensor light comes on, but it doesn't seem to be detecting my face properly.",
    priority: 'medium',
    issue_category: 'mood-sensor',
    customer_mood: 'confused',
    customer_name: 'Robert Johnson',
    email: 'rob.johnson@marketing.co',
    phone: '+1-555-0543',
    account_tier: 'premium',
    serial: 'MBP-2024-999000',
    purchase_date: 6.weeks.ago,
    created_at: 1.day.ago
  }
]

more_tickets.each do |ticket_data|
  # Create tickets with specific timestamps for realistic workflow patterns
  # Mix of different statuses for filtering demonstration
  statuses = [ 'new', 'open', 'waiting_customer', 'resolved' ]
  status_weights = [ 0.4, 0.3, 0.2, 0.1 ] # More new/open tickets than resolved
  selected_status = statuses.sample(1, random: Random.new(ticket_data[:serial].hash)).first

  ticket = Ticket.create!(
    subject: ticket_data[:subject],
    description: ticket_data[:description],
    status: selected_status,
    priority: ticket_data[:priority],
    channel: [ 'web', 'email', 'chat', 'phone' ].sample,
    machine_model: ticket_data[:serial].split('-')[0].gsub('MB', 'MoodBrew ').gsub('H', 'Home').gsub('P', 'Pro').gsub('O', 'Office').gsub('C', 'Cafe'),
    issue_category: ticket_data[:issue_category],
    customer_mood: ticket_data[:customer_mood],
    assigned_agent: selected_status == 'new' ? nil : [ agent1, agent2, supervisor ].sample,
    created_at: ticket_data[:created_at],
    updated_at: selected_status == 'resolved' ? ticket_data[:created_at] + 1.day : ticket_data[:created_at]
  )

  ticket.create_customer_info(
    customer_name: ticket_data[:customer_name],
    email: ticket_data[:email],
    phone: ticket_data[:phone],
    account_tier: ticket_data[:account_tier],
    moodbrew_serial: ticket_data[:serial],
    purchase_date: ticket_data[:purchase_date],
    warranty_status: 'active'
  )

  # Add initial customer message with realistic timestamp
  ticket.messages.create!(
    sender: 'customer',
    sender_name: ticket_data[:customer_name],
    content: ticket_data[:description],
    sent_at: ticket_data[:created_at]
  )
end

puts "    ✅ Created #{Ticket.count} sample tickets"

# Add some ticket activities for realism
puts "  📝 Adding ticket activities..."

Ticket.all.each do |ticket|
  # Add some random activities to make tickets look realistic
  if ticket.status != 'new'
    ticket.activities.create!(
      action: 'status_changed',
      description: "Status changed from new to #{ticket.status}",
      performed_by: ticket.assigned_agent&.display_name || 'System',
      performed_at: rand(1..5).days.ago
    )
  end

  if ticket.assigned_agent
    ticket.activities.create!(
      action: 'assigned',
      description: "Assigned to #{ticket.assigned_agent.display_name}",
      performed_by: 'System',
      performed_at: rand(1..3).days.ago
    )
  end
end

puts "    ✅ Added activities to tickets"

# Summary
puts <<~SUMMARY

  🎉 Seeding Complete!

  📊 Database Summary:
  ├── Agents: #{Agent.count}#{' '}
  ├── Support Tickets: #{Ticket.count}
  └── Total Documents: #{Agent.count + Ticket.count}

  🔐 Test Login Credentials:
  ├── Admin: admin@moodbrew.com / password123
  ├── Supervisor: sarah@moodbrew.com / password123#{'  '}
  ├── Agent 1: mike@moodbrew.com / password123
  └── Agent 2: emma@moodbrew.com / password123

  ☕ Ready to brew some great support experiences!

SUMMARY
