# LEARNING NOTE: FactoryBot Factories
# Factories define blueprints for creating test objects
# They're better than fixtures because they're Ruby code, not static YAML
# Reference: https://github.com/thoughtbot/factory_bot

FactoryBot.define do
  factory :agent do
    # LEARNING NOTE: Faker generates realistic fake data
    # This makes tests more realistic and catches edge cases
    name { Faker::Name.name }
    email { Faker::Internet.unique.email }
    password { "password123" }  # Simple password for tests
    password_confirmation { "password123" }  # Required for validation
    role { "agent" }

    # LEARNING NOTE: After creating the main object
    # We can use after(:create) to set up associated data
    after(:create) do |agent|
      # These embedded documents are created automatically
      # by our Agent model's initialize_metrics callback
      # But we can customize them in tests if needed
    end

    # LEARNING NOTE: Factory Traits
    # Traits let us create variations of the same factory
    # Usage: create(:agent, :supervisor) or create(:admin_agent)
    trait :supervisor do
      role { "supervisor" }
      name { "#{Faker::Name.name} (Supervisor)" }
    end

    trait :admin do
      role { "admin" }
      name { "#{Faker::Name.name} (Admin)" }
    end

    # MOODBREW THEME: Coffee-inspired test data
    trait :coffee_lover do
      name { "#{Faker::Coffee.variety} #{Faker::Name.last_name}" }
      # Custom preferences for our coffee theme
      after(:create) do |agent|
        agent.preferences.update(theme: 'coffee') if agent.preferences
        agent.performance_metrics.update(
          coffee_breaks_today: rand(1..5)
        ) if agent.performance_metrics
      end
    end
  end
end
