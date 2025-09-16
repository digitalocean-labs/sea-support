# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

SupportIQ is a comprehensive AI-powered customer support tool built as an educational Rails 8 + MongoDB application. It demonstrates modern web development practices with sophisticated AI integration for ticket management, automated classification, intelligent response suggestions, and demo data generation. The application serves as a learning platform showcasing Rails conventions, MongoDB document modeling, DigitalOcean AI service integration patterns, and advanced background job processing with comprehensive debugging capabilities.

## Architecture & Technology Stack

### Core Technologies
- **Framework**: Ruby on Rails 8.0+ 
- **Database**: MongoDB with Mongoid ODM
- **Frontend**: Rails views + Tailwind CSS + Hotwire (Turbo/Stimulus)
- **Background Jobs**: Sidekiq with comprehensive job tracking via `BackgroundJob` model
- **Testing**: RSpec with Factory Bot, Capybara, VCR, SimpleCov for coverage
- **AI Integration**: DigitalOcean Agent + Gradient AI endpoints (ruby-openai gem)
- **Authentication**: Rails 8 built-in authentication (has_secure_password)
- **Asset Pipeline**: Importmap + Tailwind CSS with custom Stimulus controllers

### Key Architectural Decisions
- **MongoDB Over PostgreSQL**: Flexible schema for AI metadata evolution and embedded documents
- **Service Objects**: Business logic encapsulation (`AiService`, `DemoTicketService`)
- **Comprehensive Job Tracking**: `BackgroundJob` model stores persistent AI processing history; Redis used for temporary debug data
- **Educational Comments**: Extensive inline documentation explaining Rails/MongoDB concepts throughout codebase
- **Dual AI Backend**: Support for both DigitalOcean Agent and Gradient AI with intelligent fallback
- **Test-First Development**: RSpec with 80%+ coverage target and MongoDB-specific testing patterns

## Development Commands

### Primary Development Commands
```bash
# Initial setup (one-time)
bin/setup                    # Install dependencies and start development server
bin/rails credentials:edit   # Configure API keys and secrets

# Daily development
bin/dev                      # Start development server with CSS watching (foreman)
bin/rails server            # Start server only (port 3000)
bin/rails console           # Rails console with MongoDB access
bin/rails generate           # Rails generators (models, controllers, etc.)

# Database operations (MongoDB-specific)
bin/rails db:mongoid:create_collections    # Create collections for models
bin/rails db:mongoid:create_indexes        # Create indexes for performance
bin/rails db:seed                          # Load sample data with MoodBrew scenarios
bin/rails db:mongoid:drop                  # Drop MongoDB database
bin/rails db:mongoid:purge                 # Clear all collections (preserves structure)

# Background job management
bundle exec sidekiq          # Start Sidekiq background job processor
bin/rails jobs:work          # Alternative job processing (if configured)
```

### Testing Commands
```bash
# Test execution
bundle exec rspec                    # Run all tests
bundle exec rspec spec/models/       # Run model tests only
bundle exec rspec spec/controllers/  # Run controller tests
bundle exec rspec --tag focus        # Run focused tests only
bundle exec rspec --format documentation # Verbose test output

# Test utilities
bundle exec rspec --profile          # Show slowest tests
bin/rails spec:coverage              # Generate coverage report (if available)
```

### Code Quality & Linting
```bash
# Code linting and formatting
bundle exec rubocop                  # Run Ruby linter (Rails Omakase rules)
bundle exec rubocop -a               # Auto-fix issues
bundle exec brakeman                 # Security vulnerability scanning
```

### Asset Management
```bash
bin/rails tailwindcss:build         # Build Tailwind CSS
bin/rails tailwindcss:watch         # Watch CSS changes
bin/rails assets:precompile          # Compile all assets (production)
```

### MongoDB-Specific Operations
```bash
# MongoDB management
bin/rails db:mongoid:purge           # Clear all non-system collections
bin/rails db:mongoid:create_search_indexes  # Create text search indexes
bin/rails db:create_indexes          # Ensure all indexes exist
```

## Code Structure & Conventions

### Models (app/models/)
- **Document-based**: Include `Mongoid::Document` instead of inheriting from `ApplicationRecord`
- **Embedded Documents**: Use `embeds_one`/`embeds_many` for tightly coupled data (`AiAnalysis`, `CustomerInfo`, `Message`)
- **Advanced Models**: 
  - `Ticket`: Main entity with embedded AI analysis and customer info
  - `BackgroundJob`: Comprehensive AI processing tracking with debug data
  - `Agent`: Authentication and performance metrics
- **Indexes**: Explicitly define indexes for query performance (text search, compound indexes)
- **Validations**: Standard Rails validations work with Mongoid

### Controllers (app/controllers/)
- **Skinny Controllers**: Delegate business logic to service objects
- **RESTful Routes**: Follow Rails conventions with AI-specific and demo endpoints
- **Authentication**: Uses `authenticate_agent!` before_action
- **New Features**:
  - Demo ticket generation (`/tickets/generate_demo_ticket`)
  - Comprehensive AI analysis endpoints with debug capabilities
  - Background job monitoring and status tracking

### Services (app/services/)
- **AI Integration**: `AiService` for comprehensive ticket analysis with DigitalOcean integration
- **Demo Generation**: `DemoTicketService` for AI-powered realistic ticket scenarios
- **Result Objects**: Use Result pattern for success/failure handling
- **Error Handling**: Graceful degradation with multiple fallback mechanisms

### Views (app/views/)
- **Tailwind CSS**: Utility-first CSS framework with custom demo styling
- **Hotwire**: Turbo for SPA-like experience, Stimulus for interactive demo features
- **ERB Templates**: Comprehensive templates with educational comments and accessibility features
- **Interactive Features**: Demo ticket generation UI with loading states and visual feedback

### Background Jobs (app/jobs/)
- **Sidekiq**: Advanced background processing for AI analysis with retry strategies
- **Comprehensive Tracking**: `BackgroundJob` model stores complete request/response cycles
- **Retry Logic**: Exponential backoff for different error types (rate limits, API errors)
- **Debug Capabilities**: Complete console logs and step-by-step processing tracking
- **Admin Interface**: Rich monitoring at `/admin/background_jobs` with job details

## Testing Strategy

### RSpec Configuration
- **Database Cleaner**: Uses `database_cleaner-mongoid` for test isolation
- **Factory Bot**: Test data generation (preferred over fixtures for MongoDB)
- **VCR + WebMock**: AI API call mocking and recording
- **Capybara**: End-to-end testing with Selenium WebDriver

### Test Structure
```
spec/
├── models/           # Unit tests for Mongoid documents
├── controllers/      # Controller action tests
├── services/         # Service object tests with mocked AI calls
├── system/          # End-to-end user journey tests
├── factories/       # Factory Bot definitions
└── support/         # Test helpers and shared examples
```

### Key Test Patterns
- **AI Service Mocking**: Use VCR cassettes for consistent AI responses
- **Database Transactions**: MongoDB doesn't support transactions like SQL - use database cleaner
- **Factory Pattern**: Build realistic test data with Faker gem
- **System Tests**: Test complete user workflows (login → create ticket → AI analysis)

## Demo Ticket Generation Feature

### AI-Powered Demo System
The application includes a sophisticated demo ticket generation system that creates realistic MoodBrew support scenarios:

**Location**: New ticket form (`/tickets/new`) - prominent purple section at top
**Components**:
- `DemoTicketService` - AI-powered ticket scenario generation
- `demo_ticket_controller.js` - Stimulus controller for form interaction
- Demo UI with loading states, error handling, and visual feedback

### Demo Service Architecture
```ruby
# app/services/demo_ticket_service.rb
class DemoTicketService
  def generate_demo_ticket
    # Uses same DigitalOcean AI endpoints as main application
    # Falls back to curated static scenarios if AI fails
    # Returns complete ticket data including customer profiles
  end
  
  private
  
  def generate_fallback_demo_ticket
    # 5 curated scenarios covering different customer personas:
    # - Coffee emergencies, feature requests, technical issues
    # - Various customer moods and priorities
    # - Realistic MoodBrew product context
  end
end
```

### Demo Feature Usage
1. **Navigate to**: `/tickets/new`
2. **Click**: "Generate Demo Ticket" button in purple section
3. **AI generates**: Realistic scenario with customer personality
4. **Form populates**: All fields with visual highlighting animation
5. **User can**: Modify data, generate new scenario, or submit ticket
6. **Fallback**: Static scenarios if AI unavailable

### Demo Scenarios Include
- **Coffee Emergencies**: "Machine thinks I'm always sad ☹️"
- **Feature Requests**: "Hangover mode please! 🍷➡️☕"
- **Technical Issues**: "App won't connect to my MoodBrew Office"  
- **Maintenance**: "Strange grinding noise from my MoodBrew Pro"
- **Critical Problems**: "HELP! No coffee for 3 days"

## AI Integration Patterns

### Service Architecture
```ruby
# Comprehensive AI service with dual backend support
class AiService
  def initialize(enable_debug = false, background_job = nil)
    # Supports both DigitalOcean Agent and Gradient AI
    # Automatic fallback between endpoints
    # Comprehensive debug tracking via BackgroundJob model
  end
  
  def analyze_ticket(ticket, include_response = true)
    # Direct AI analysis without local context
    # DigitalOcean Agent has built-in RAG capabilities
    
    # AI analysis with step-by-step debug tracking
    ai_response = call_ai_with_context(ticket, context)
    
    # Optional response generation
    if include_response && high_confidence?
      suggested_response = generate_response(ticket)
    end
    
    # Complete tracking in BackgroundJob model
    store_debug_data(ai_response, processing_steps)
  end
end
```

### Configuration Management
- **Dual AI Backends**: DigitalOcean Agent (preferred) + Gradient AI (fallback)
- **Credentials**: Use Rails encrypted credentials for API keys
- **Environment Variables**: MongoDB connection, AI endpoints, debug flags
- **Error Handling**: Graceful degradation with multiple fallback layers
- **Comprehensive Tracking**: Complete request/response cycles stored in `BackgroundJob` model

## Development Workflow

### Feature Development Process
1. **Write Tests First**: Start with RSpec specs for new features
2. **Create Service Objects**: Business logic goes in `app/services/`
3. **Update Models**: Add fields and validations as needed (MongoDB flexible schema)
4. **Build Controllers**: Keep them thin, delegate to services
5. **Add Views**: Use Tailwind CSS classes and Hotwire patterns
6. **Run Test Suite**: Ensure all tests pass before committing

### MongoDB Schema Evolution
- **Flexible Fields**: Add new fields to documents without migrations
- **Embedded Documents**: Update structure by modifying model definitions
- **Indexes**: Add new indexes through `bin/rails db:create_indexes`
- **Data Migration**: Use Rails tasks or console commands for bulk updates

## Configuration Files

### Key Configuration
- **config/mongoid.yml**: MongoDB connection settings (development/test/production)
- **config/routes.rb**: RESTful routes + AI-specific endpoints
- **Gemfile**: Dependencies with extensive learning comments
- **.rspec**: RSpec configuration for test execution
- **Procfile.dev**: Development server processes (web + CSS watching)

### Environment Setup
- **Development**: Uses local MongoDB or DigitalOcean connection
- **Test**: Separate test database (supportiq_test) 
- **Production**: DigitalOcean Managed MongoDB with SSL

## Common Development Tasks

### Adding New AI Features
1. Create service object in `app/services/`
2. Add background job in `app/jobs/` if needed
3. Update ticket model with new AI metadata fields
4. Write RSpec tests with VCR cassettes
5. Add controller actions and routes
6. Build UI components with Tailwind

### Debugging AI Integration
```bash
# Debug endpoints for development
GET /tickets/:id/debug_rag        # RAG response data from DigitalOcean Agent
GET /tickets/:id/debug_progress   # Step-by-step processing timing
GET /tickets/:id/debug_logs       # Complete console logs

# Background job debugging
GET /admin/background_jobs        # Job monitoring dashboard
GET /admin/background_jobs/:id    # Detailed job information

# Rails console debugging
bin/rails console
> ticket = Ticket.first
> job = BackgroundJob.for_ticket(ticket.id).recent.first
> job.processing_steps            # See step-by-step execution
> job.rag_retrieval_data         # RAG sources and scores
> job.console_logs               # Complete debug output

# Test demo ticket generation
> service = DemoTicketService.new
> demo_data = service.generate_demo_ticket
> puts demo_data[:subject]       # See generated scenario
```

### Performance Optimization
- **MongoDB Indexes**: Check `db.tickets.getIndexes()` in MongoDB shell
- **Connection Pooling**: Configured in `config/mongoid.yml`
- **Background Processing**: Move slow AI calls to Sidekiq jobs
- **Caching**: Redis for temporary debug data (1hr TTL), MongoDB for persistent analysis results

## Common Issues & Solutions

### MongoDB Connection Issues
- Check `MONGODB_URI` environment variable
- Verify DigitalOcean Managed MongoDB credentials
- Check SSL settings for production connections

### AI Service Failures
- Services degrade gracefully (continue without AI analysis)
- Check API key configuration in Rails credentials
- Monitor rate limits and quota usage

### Test Database Cleanup
- Use `DatabaseCleaner.clean` between tests
- MongoDB doesn't support transactions like SQL databases
- Factory Bot creates realistic test data

## Key Files & Components

### Core Application Files
- **`app/models/ticket.rb`**: Main ticket entity with embedded documents (`AiAnalysis`, `CustomerInfo`)
- **`app/models/background_job.rb`**: Comprehensive AI job tracking with debug data storage
- **`app/services/ai_service.rb`**: Primary AI integration with DigitalOcean endpoints
- **`app/services/demo_ticket_service.rb`**: AI-powered demo scenario generation
- **`app/jobs/ai_analysis_job.rb`**: Background job with retry strategies and error handling
- **`app/controllers/tickets_controller.rb`**: Comprehensive ticket management with demo generation
- **`app/javascript/controllers/demo_ticket_controller.js`**: Stimulus controller for interactive demo features

### Configuration Files
- **`config/mongoid.yml`**: MongoDB connection settings with production optimizations
- **`config/routes.rb`**: RESTful routes with AI-specific and demo endpoints
- **`config/importmap.rb`**: JavaScript module management for Stimulus controllers
- **`Gemfile`**: Dependencies with extensive learning comments
- **`Procfile.dev`**: Development server processes (web + CSS watching)

### Frontend Assets  
- **`app/views/tickets/new.html.erb`**: New ticket form with integrated demo generation UI
- **`app/assets/stylesheets/demo_ticket.css`**: Custom styling for demo features
- **Tailwind CSS**: Utility-first styling with custom demo animations

### Testing Infrastructure
- **`spec/`**: RSpec test suite with MongoDB-specific patterns
- **`.rspec`**: RSpec configuration for test execution
- **VCR cassettes**: AI API call mocking for consistent testing

## Educational Notes

This codebase is designed as a comprehensive learning platform with extensive comments explaining:
- **Rails Conventions**: Why we follow certain patterns and Rails doctrine
- **MongoDB Concepts**: Document modeling vs relational thinking, embedded documents, indexes
- **AI Integration**: Service patterns, error handling, dual backend support
- **Testing Strategies**: MongoDB-specific testing approaches, VCR usage, factory patterns
- **Background Jobs**: Sidekiq patterns, retry strategies, comprehensive job tracking
- **Demo Features**: AI-powered content generation, interactive UI patterns

Look for `# LEARNING NOTE:` and `# BEST PRACTICE:` comments throughout the code for detailed explanations of architectural decisions and implementation patterns. The application serves as both a functional support tool and an educational resource for modern Rails development with AI integration.