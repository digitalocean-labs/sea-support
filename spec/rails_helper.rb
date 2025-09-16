# LEARNING NOTE: RSpec Rails Helper
# This file sets up RSpec for Rails-specific testing
# It's different from spec_helper.rb which handles pure Ruby testing

require 'spec_helper'
ENV['RAILS_ENV'] ||= 'test'
require_relative '../config/environment'
# Prevent database truncation if the environment is production
abort("The Rails environment is running in production mode!") if Rails.env.production?
require 'rspec/rails'

# LEARNING NOTE: MongoDB Test Configuration
# We need special setup for MongoDB since it doesn't use ActiveRecord
require 'database_cleaner-mongoid'
require 'factory_bot_rails'
require 'faker'
require 'simplecov'

# LEARNING NOTE: Code Coverage with SimpleCov
# This tracks what percentage of our code is tested (target: 80%+)
SimpleCov.start 'rails' do
  add_filter '/spec/'
  add_filter '/config/'
  add_filter '/vendor/'
end

# Add additional requires below this line. Rails is not loaded until this point!

# Requires supporting ruby files with custom matchers and macros, etc, in
# spec/support/ and its subdirectories. Files matching `spec/**/*_spec.rb` are
# run as spec files by default. This means that files in spec/support that end
# in _spec.rb will both be required and run as specs, causing the specs to be
# run twice. It is recommended that you do not name files matching this glob to
# end with _spec.rb. You can configure this pattern with the --pattern
# option on the command line or in ~/.rspec, .rspec or `.rspec-local`.
#
# The following line is provided for convenience purposes. It has the downside
# of increasing the boot-up time by auto-requiring all files in the support
# directory. Alternatively, in the individual `*_spec.rb` files, manually
# require only the support files necessary.
#
# LEARNING NOTE: Loading Support Files
# Uncomment this to auto-load all files in spec/support/
Rails.root.glob('spec/support/**/*.rb').sort_by(&:to_s).each { |f| require f }

RSpec.configure do |config|
  # LEARNING NOTE: Disable ActiveRecord
  # We're using MongoDB/Mongoid, not ActiveRecord
  config.use_active_record = false

  # LEARNING NOTE: Include FactoryBot Methods
  # This lets us use `create(:agent)` instead of `FactoryBot.create(:agent)`
  config.include FactoryBot::Syntax::Methods
  
  # LEARNING NOTE: Database Cleaner for MongoDB
  # MongoDB doesn't support transactions like SQL databases
  # We need to clean the database between tests manually
  config.before(:suite) do
    DatabaseCleaner[:mongoid].strategy = :deletion
    DatabaseCleaner[:mongoid].clean_with(:deletion)
  end
  
  config.around(:each) do |example|
    DatabaseCleaner[:mongoid].cleaning do
      example.run
    end
  end
  
  # BEST PRACTICE: Create test data efficiently
  config.before(:each) do
    # Any global test setup here
  end

  # RSpec Rails uses metadata to mix in different behaviours to your tests,
  # for example enabling you to call `get` and `post` in request specs. e.g.:
  #
  #     RSpec.describe UsersController, type: :request do
  #       # ...
  #     end
  #
  # The different available types are documented in the features, such as in
  # https://rspec.info/features/7-1/rspec-rails
  #
  # You can also this infer these behaviours automatically by location, e.g.
  # /spec/models would pull in the same behaviour as `type: :model` but this
  # behaviour is considered legacy and will be removed in a future version.
  #
  # To enable this behaviour uncomment the line below.
  config.infer_spec_type_from_file_location!

  # Filter lines from Rails gems in backtraces.
  config.filter_rails_from_backtrace!
  # arbitrary gems may also be filtered via:
  # config.filter_gems_from_backtrace("gem name")
  
  # LEARNING NOTE: VCR Configuration for API Testing
  # This will record HTTP requests to AI services for consistent testing
  # We'll configure this when we add AI integration
end

# LEARNING NOTE: Custom RSpec Matchers
# You can add custom matchers here for domain-specific testing
# For example: expect(ticket).to be_high_priority
