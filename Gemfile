source "https://rubygems.org"

# Bundle edge Rails instead: gem "rails", github: "rails/rails", branch: "main"
gem "rails", "~> 8.0.2"
# The modern asset pipeline for Rails [https://github.com/rails/propshaft]
gem "propshaft"
# Use the Puma web server [https://github.com/puma/puma]
gem "puma", ">= 5.0"
# Use JavaScript with ESM import maps [https://github.com/rails/importmap-rails]
gem "importmap-rails"
# Hotwire's SPA-like page accelerator [https://turbo.hotwired.dev]
gem "turbo-rails"
# Hotwire's modest JavaScript framework [https://stimulus.hotwired.dev]
gem "stimulus-rails"
# Use Tailwind CSS [https://github.com/rails/tailwindcss-rails]
gem "tailwindcss-rails"
# Use Redis adapter to run Action Cable in production
gem "redis", ">= 4.0.1"

# LEARNING NOTE: Authentication
# bcrypt is needed for secure password hashing (even with MongoDB)
# This is used by has_secure_password in our Agent model
gem "bcrypt", "~> 3.1.7"

# LEARNING NOTE: MongoDB Integration
# Mongoid is the official MongoDB ODM (Object-Document Mapper) for Rails
# It replaces ActiveRecord when using MongoDB instead of SQL databases
gem "mongoid", "~> 9.0"

# LEARNING NOTE: AI and HTTP Services
# These gems will help us integrate with AI services
gem "httparty"  # Simple HTTP client for API calls
gem "ruby-openai"  # OpenAI API client for AI features
gem "redcarpet"  # Markdown processing for AI-generated responses

# LEARNING NOTE: Background Jobs
# Even though Rails 8 has Solid Queue, it requires Active Record
# We'll use Sidekiq with MongoDB for background processing
gem "sidekiq", "~> 8.0"

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem "tzinfo-data", platforms: %i[ windows jruby ]

# Reduces boot times through caching; required in config/boot.rb
gem "bootsnap", require: false

# Deploy this application anywhere as a Docker container [https://kamal-deploy.org]
gem "kamal", require: false

# Add HTTP asset caching/compression and X-Sendfile acceleration to Puma [https://github.com/basecamp/thruster/]
gem "thruster", require: false

group :development, :test do
  # See https://guides.rubyonrails.org/debugging_rails_applications.html#debugging-with-the-debug-gem
  gem "debug", platforms: %i[ mri windows ], require: "debug/prelude"

  # Static analysis for security vulnerabilities [https://brakemanscanner.org/]
  gem "brakeman", require: false

  # Omakase Ruby styling [https://github.com/rails/rubocop-rails-omakase/]
  gem "rubocop-rails-omakase", require: false

  # LEARNING NOTE: Environment Variables
  # dotenv loads .env files for development (like DATABASE_URL, API keys)
  # Production uses real environment variables instead
  gem "dotenv-rails"

  # LEARNING NOTE: Testing Stack
  # RSpec is the most popular testing framework for Rails (alternative to Minitest)
  # It provides a more readable DSL (Domain Specific Language) for tests
  gem "rspec-rails", "~> 7.1"

  # Rails controller testing helpers (assigns, render_template, etc.)
  gem "rails-controller-testing"

  # Factory Bot creates test data (better than fixtures for MongoDB)
  # Follows the Factory pattern - builds objects for testing
  gem "factory_bot_rails"

  # Faker generates realistic test data (names, emails, coffee products!)
  gem "faker"
end

group :development do
  # Use console on exceptions pages [https://github.com/rails/web-console]
  gem "web-console"
end

group :test do
  # Use system testing [https://guides.rubyonrails.org/testing.html#system-testing]
  gem "capybara"
  gem "selenium-webdriver"

  # LEARNING NOTE: Additional Testing Tools
  # Database Cleaner ensures a clean database state between tests
  # Essential for MongoDB since transactions work differently than SQL
  gem "database_cleaner-mongoid"

  # VCR records HTTP requests for consistent AI service testing
  # This prevents hitting real APIs during tests and ensures speed
  gem "vcr"
  gem "webmock"  # Works with VCR to stub HTTP requests

  # SimpleCov generates code coverage reports
  # Helps ensure we're testing enough of our code (target: 80%+)
  gem "simplecov", require: false
end
