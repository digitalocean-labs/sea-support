# SupportIQ ☕ 
### AI-Powered Customer Support Platform for MoodBrew Coffee Machines

[![Rails](https://img.shields.io/badge/Rails-8.0+-red.svg)](https://rubyonrails.org/)
[![MongoDB](https://img.shields.io/badge/MongoDB-7.0+-green.svg)](https://www.mongodb.com/)
[![DigitalOcean AI](https://img.shields.io/badge/DigitalOcean-AI%20Integration-blue.svg)](https://www.digitalocean.com/products/ai-ml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

---

## 🎯 What is SupportIQ?

SupportIQ is a comprehensive AI-powered customer support platform that demonstrates modern web development with sophisticated AI integration. Built as an educational Rails 8 + MongoDB application, it showcases how artificial intelligence can transform customer support operations while maintaining human oversight and control.

**Demo Context:** The application manages support tickets for **MoodBrew** - a fictional AI-powered smart coffee machine that detects users' moods and brews the perfect coffee accordingly. From "morning monster" emergencies to "hangover mode" feature requests, SupportIQ handles it all with intelligence and humor.

### ✨ Key Features

- 🤖 **AI-Powered Ticket Analysis**: Automatic classification, tagging, and priority assignment
- 📝 **Intelligent Response Suggestions**: AI-generated customer responses with confidence scoring
- 🎭 **Demo Ticket Generator**: Create realistic support scenarios for testing and demos
- 📊 **Comprehensive Analytics**: Track AI performance and agent productivity
- 🔍 **Advanced Search**: Full-text search across tickets with MongoDB text indexes
- ⚡ **Real-time Processing**: Background jobs with detailed monitoring
- 🎨 **Modern UI**: Tailwind CSS with interactive Stimulus controllers
- 🧠 **DigitalOcean Agent Integration**: Context-aware AI responses using built-in RAG capabilities

---

## 🚀 Quick Start

### Prerequisites

- **Ruby 3.3+** with Rails 8.0+
- **MongoDB 7.0+** (local or DigitalOcean Managed)
- **Node.js 18+** for asset compilation
- **DigitalOcean Account** (for AI services)

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/yourusername/supportiq.git
   cd supportiq
   ```

2. **Install dependencies**
   ```bash
   bundle install
   npm install  # For Tailwind CSS compilation
   ```

3. **Configure environment**
   ```bash
   # Copy environment template
   cp .env.example .env
   
   # Edit with your settings
   nano .env
   ```

4. **Set up credentials**
   ```bash
   # Configure Rails encrypted credentials
   bin/rails credentials:edit
   
   # Add your DigitalOcean Agent key:
   # digitalocean:
   #   agent_access_key: your_agent_access_key
   ```

5. **Configure MongoDB**
   ```bash
   # Edit MongoDB connection
   nano config/mongoid.yml
   
   # For local MongoDB:
   # MONGODB_URI=mongodb://localhost:27017/supportiq_development
   
   # For DigitalOcean Managed MongoDB:
   # MONGODB_URI=mongodb+srv://user:pass@cluster.mongodb.net/supportiq
   ```

6. **Initialize the database**
   ```bash
   # Create collections and indexes
   bin/rails db:mongoid:create_collections
   bin/rails db:mongoid:create_indexes
   
   # Load sample data
   bin/rails db:seed
   ```

7. **Start the application**
   ```bash
   # Development mode with CSS watching
   bin/dev
   
   # Or start components separately:
   bin/rails server          # Rails app (port 3000)
   bundle exec sidekiq       # Background jobs
   ```

8. **Visit the application**
   ```
   http://localhost:3000
   ```

---

## 🎮 Usage Guide

### Getting Started

1. **Sign Up/Login**: Create an agent account to access the dashboard
2. **Explore Sample Tickets**: The seed data includes various MoodBrew support scenarios
3. **Try AI Analysis**: Click "Analyze" on any ticket to see AI-powered insights
4. **Generate Demo Tickets**: Use the "Generate Demo Ticket" feature for realistic test data

### Core Workflows

#### 🎭 Generating Demo Tickets
Perfect for testing and demonstrations:

1. Navigate to **Create New Ticket** (`/tickets/new`)
2. Click **"Generate Demo Ticket"** in the purple section
3. Watch AI create realistic MoodBrew scenarios with customer personalities
4. Modify the generated data or create another scenario
5. Submit to create the ticket

**Sample Generated Scenarios:**
- "Coffee emergency! Machine thinks I'm always sad ☹️"
- "Feature request: Hangover mode please! 🍷➡️☕"
- "App won't connect to my MoodBrew Office"

#### 🤖 AI Ticket Analysis
Transform raw support requests into actionable insights:

1. Open any ticket from the dashboard
2. Click **"Analyze with AI"** 
3. AI analyzes using MoodBrew knowledge base context
4. Review generated tags, priority, sentiment, and summary
5. Approve, modify, or reject AI suggestions
6. Generate customer response suggestions

#### 📊 Monitoring AI Performance
Track how well your AI is performing:

1. Visit **Admin > Background Jobs** for detailed job monitoring
2. Check **Analytics Dashboard** for AI accuracy metrics
3. Review individual ticket analysis debug data
4. Monitor processing times and success rates

### Advanced Features

#### 🔍 Debug Mode
For development and troubleshooting:

```ruby
# Rails console debugging
bin/rails console

# Test AI service directly
> ticket = Ticket.first
> service = AiService.new(true)  # Enable debug mode
> result = service.analyze_ticket(ticket)

# Check background job details
> job = BackgroundJob.recent.first
> job.processing_steps  # Step-by-step execution
> job.console_logs      # Complete debug output
```

#### 🔧 Background Job Monitoring
Real-time visibility into AI processing:

- **Job Dashboard**: `/admin/background_jobs`
- **Individual Job Details**: Complete request/response data
- **Retry Management**: Automatic exponential backoff
- **Error Tracking**: Comprehensive error logging with stack traces

---

## 🏗️ Architecture Overview

### Technology Stack

| Component | Technology | Purpose |
|-----------|------------|---------|
| **Backend** | Ruby on Rails 8 | Web framework with modern conventions |
| **Database** | MongoDB + Mongoid | Flexible document storage for AI metadata |
| **AI Integration** | DigitalOcean Agent | Specialized AI agent with built-in RAG capabilities |
| **Frontend** | Tailwind CSS + Stimulus | Modern, responsive UI with interactive features |
| **Background Jobs** | Sidekiq | Reliable AI processing with retry logic |
| **Testing** | RSpec + VCR + Factory Bot | Comprehensive test coverage with AI mocking |

### Data Model Highlights

```ruby
# Ticket with embedded documents (MongoDB advantage)
class Ticket
  include Mongoid::Document
  
  field :subject, type: String
  field :description, type: String
  field :priority, type: String
  field :status, type: String
  
  # AI analysis embedded directly in ticket
  embeds_one :ai_analysis
  
  # Customer info embedded for performance
  embeds_one :customer_info
  
  # Messages embedded for complete ticket context
  embeds_many :messages
end
```

### AI Service Architecture

```ruby
# DigitalOcean Agent integration with built-in RAG
class AiService
  def analyze_ticket(ticket, include_response = true)
    # 1. Build comprehensive analysis prompt
    prompt = build_analysis_prompt(ticket)
    
    # 2. Call DigitalOcean Agent with RAG retrieval enabled
    response = @client.chat(
      parameters: {
        messages: [{ role: "user", content: prompt }],
        extra_body: {
          include_retrieval_info: true,
          include_functions_info: true
        }
      }
    )
    
    # 3. Parse structured JSON response with confidence scoring
    analysis_result = parse_ai_response(response, ticket)
    
    # 4. Generate customer response if high confidence (>70%)
    if include_response && analysis_result[:confidence_score] > 0.7
      analysis_result[:suggested_response] = generate_response(ticket)
    end
    
    # 5. Store complete processing details for monitoring
    store_debug_data(response, analysis_result)
  end
end
```

---

## 🧪 Demo Scenarios

SupportIQ comes with engaging MoodBrew support scenarios that showcase different AI capabilities:

### High-Priority Emergencies
```
Subject: "COFFEE MACHINE BROKEN - NO COFFEE FOR 3 DAYS!!!"
Customer: Mike (Angry morning person)
AI Analysis: 
- Priority: URGENT
- Sentiment: Very Negative  
- Tags: [brewing-failure, mood-sensor, refund-request]
- Confidence: 95%
```

### Feature Requests  
```
Subject: "Feature Request: Hangover mode please! 🍷➡️☕"
Customer: Sarah (Happy but needs stronger coffee)
AI Analysis:
- Priority: LOW
- Sentiment: Positive
- Tags: [feature-request, mood-profiles, weekend-mode]
- Confidence: 88%
```

### Technical Issues
```
Subject: "App won't connect to my MoodBrew Office"  
Customer: Corporate IT team
AI Analysis:
- Priority: MEDIUM
- Sentiment: Concerned
- Tags: [connectivity, app-integration, office-setup]
- Confidence: 92%
```

---

## 🛠️ Development

### Running Tests

```bash
# Full test suite
bundle exec rspec

# Specific test files
bundle exec rspec spec/models/ticket_spec.rb
bundle exec rspec spec/services/ai_service_spec.rb

# Generate coverage report
bundle exec rspec --format documentation
```

### Code Quality

```bash
# Ruby linting (Rails Omakase style)
bundle exec rubocop

# Security scanning
bundle exec brakeman

# Auto-fix style issues
bundle exec rubocop -a
```

### Database Operations

```bash
# MongoDB specific operations
bin/rails db:mongoid:create_indexes     # Performance indexes
bin/rails db:mongoid:create_search_indexes  # Full-text search
bin/rails db:mongoid:purge              # Clear all data
bin/rails db:seed                       # Load sample MoodBrew data
```

### Background Jobs

```bash
# Start Sidekiq processor
bundle exec sidekiq

# Monitor job queue
# Visit: http://localhost:4567 (Sidekiq web UI)

# Process jobs manually (development)
bin/rails jobs:work
```

---

## 📚 Learning Resources

This project serves as an educational platform demonstrating:

- **Rails 8 Conventions**: Modern Rails patterns and best practices
- **MongoDB Document Modeling**: Embedded documents, indexes, aggregations
- **AI Integration Patterns**: Service objects, error handling, fallback strategies  
- **Background Job Processing**: Sidekiq patterns, retry logic, monitoring
- **Testing AI Applications**: VCR cassettes, factory patterns, mock strategies

### Educational Comments

The codebase includes extensive `# LEARNING NOTE:` comments explaining:
- Why certain architectural decisions were made
- MongoDB vs SQL patterns and trade-offs
- AI service integration best practices
- Rails conventions and modern patterns

---

## 🚀 Deployment

### DigitalOcean App Platform

1. **Create app from GitHub**:
   ```bash
   # Using doctl CLI
   doctl apps create --spec .do/app.yaml
   ```

2. **Configure environment variables**:
   - `MONGODB_URI`: Your managed MongoDB connection string
   - `DO_AGENT_ENDPOINT`: DigitalOcean Agent API endpoint
   - `DO_AGENT_ACCESS_KEY`: DigitalOcean Agent access key
   - `RAILS_MASTER_KEY`: Your Rails credentials key

3. **Deploy**:
   ```bash
   doctl apps create-deployment <app-id>
   ```

### Docker Deployment

```bash
# Build image
docker build -t supportiq .

# Run with environment
docker run -p 3000:3000 \
  -e MONGODB_URI=your_mongo_uri \
  -e DO_AGENT_ENDPOINT=your_agent_endpoint \
  -e DO_AGENT_ACCESS_KEY=your_agent_key \
  supportiq
```

---

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/amazing-feature`
3. Follow the existing code style and add tests
4. Commit with descriptive messages: `git commit -m "Add amazing feature"`
5. Push to your fork: `git push origin feature/amazing-feature`
6. Open a Pull Request

### Development Guidelines

- Add tests for new features (aim for 80%+ coverage)
- Include `# LEARNING NOTE:` comments for educational value
- Follow Rails conventions and MongoDB best practices
- Test AI integrations with VCR cassettes
- Update documentation for user-facing changes

---

## 📝 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

## 🙏 Acknowledgments

- **DigitalOcean** for AI services and managed MongoDB
- **Ruby on Rails** community for excellent documentation
- **MongoDB** for flexible document modeling
- **The Coffee Community** for inspiring MoodBrew scenarios ☕

---

## 📞 Support

- 🐛 **Bug Reports**: [GitHub Issues](https://github.com/yourusername/supportiq/issues)
- 💡 **Feature Requests**: [GitHub Discussions](https://github.com/yourusername/supportiq/discussions)
- 📧 **Questions**: Open an issue with the `question` label
- 📚 **Documentation**: See [CLAUDE.md](CLAUDE.md) for development guidance

---

<div align="center">

**Built with ❤️ and ☕ for the modern support experience**

[Demo](https://supportiq-demo.com) • [Documentation](CLAUDE.md) • [Contributing](CONTRIBUTING.md)

</div>