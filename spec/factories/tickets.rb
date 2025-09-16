# spec/factories/tickets.rb
# LEARNING NOTE: Factory Bot for Test Data Generation
# Factories create test objects with realistic data using Faker

FactoryBot.define do
  factory :ticket do
    # LEARNING NOTE: Faker generates realistic test data
    subject { "#{Faker::Appliance.equipment} not working properly" }
    description { Faker::Lorem.paragraph(sentence_count: 3) }
    status { 'new' }
    priority { 'medium' }
    channel { 'web' }
    
    # MOODBREW SPECIFIC
    machine_model { ['MoodBrew Pro', 'MoodBrew Home', 'MoodBrew Office'].sample }
    issue_category { ['brewing', 'maintenance', 'connectivity', 'mood-sensor'].sample }
    customer_mood { ['neutral', 'frustrated', 'angry', 'happy'].sample }
    
    # LEARNING NOTE: Associations
    # Can be overridden when creating: create(:ticket, assigned_agent: agent)
    assigned_agent { nil }
    
    # LEARNING NOTE: Traits for different ticket scenarios
    trait :with_customer do
      after(:build) do |ticket|
        ticket.build_customer_info(
          customer_name: Faker::Name.name,
          email: Faker::Internet.email,
          phone: Faker::PhoneNumber.phone_number,
          account_tier: ['free', 'premium', 'enterprise'].sample,
          moodbrew_serial: "MB-#{Faker::Alphanumeric.alphanumeric(number: 10).upcase}",
          purchase_date: Faker::Date.between(from: 2.years.ago, to: Date.today)
        )
      end
    end
    
    trait :with_ai_analysis do
      after(:create) do |ticket|
        ticket.create_ai_analysis(
          tags: ['brewing-issue', 'hardware', 'urgent'].sample(2),
          summary: "Customer experiencing #{ticket.issue_category} issues with #{ticket.machine_model}",
          sentiment: ['negative', 'neutral', 'positive'].sample,
          priority_suggestion: ['high', 'medium', 'low'].sample,
          suggested_response: Faker::Lorem.paragraph,
          confidence_score: rand(0.5..1.0).round(2),
          processed_at: Time.current,
          processing_time_ms: rand(500..3000)
        )
      end
    end
    
    trait :with_messages do
      after(:create) do |ticket|
        # Customer initial message
        ticket.messages.create!(
          sender: 'customer',
          sender_name: ticket.customer_info&.customer_name || 'Customer',
          content: ticket.description,
          sent_at: ticket.created_at
        )
        
        # Agent response
        ticket.messages.create!(
          sender: 'agent',
          sender_name: 'Support Agent',
          content: "Thank you for contacting MoodBrew support. I'll help you with this issue.",
          sent_at: ticket.created_at + 5.minutes
        )
      end
    end
    
    trait :high_priority do
      priority { 'high' }
      customer_mood { 'angry' }
      subject { "URGENT: #{Faker::Appliance.equipment} completely broken!" }
    end
    
    trait :resolved do
      status { 'resolved' }
      after(:create) do |ticket|
        ticket.activities.create!(
          action: 'resolved',
          description: 'Issue resolved successfully',
          performed_by: 'Support Agent',
          performed_at: Time.current
        )
      end
    end
    
    trait :assigned do
      association :assigned_agent, factory: :agent
    end
    
    # LEARNING NOTE: Complete ticket with all data
    trait :complete do
      with_customer
      with_ai_analysis
      with_messages
      assigned
    end
  end
end