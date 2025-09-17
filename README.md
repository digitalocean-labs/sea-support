# Sea Support: Rails, MongoDB, & DigitalOcean Gradient AI Reference App
Reference application for building AI-powered customer support platform with Gradient AI, MongoDB, Ruby on Rails, and Sidekiq.

[![Rails](https://img.shields.io/badge/Rails-8.0+-red.svg)](https://rubyonrails.org/)
[![MongoDB](https://img.shields.io/badge/MongoDB-7.0+-green.svg)](https://www.mongodb.com/)
[![DigitalOcean AI](https://img.shields.io/badge/DigitalOcean-AI%20Integration-blue.svg)](https://www.digitalocean.com/products/ai-ml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

---

Sea Support is an educational Rails application that shows how to build a modern customer support platform with AI integration. Think of it as a complete example of how AI can transform customer service while keeping humans in control.

We've built it around **MoodBrew** - an imaginary smart coffee machine that reads your mood and brews accordingly. From panicked "no coffee for 3 days!" emergencies to feature requests like "hangover mode please!", Sea Support handles real-world support scenarios with a coffee-themed twist.

![support_tickets_dashboard](https://github.com/user-attachments/assets/df4bee13-ffc9-414d-b47d-86ec07333242)

### What You'll Learn

- **Rails 8 + MongoDB**: Modern Rails patterns with flexible document storage
- **AI Integration**: DigitalOcean Agent + Gradient AI with intelligent fallbacks
- **Background Processing**: Sidekiq jobs with comprehensive monitoring
- **Modern UI**: Tailwind CSS with Hotwire and Stimulus controllers
- **Testing**: RSpec with MongoDB patterns and AI service mocking

### Key Features

- 🤖 **Smart Ticket Analysis** - AI automatically tags, prioritizes, and analyzes tickets
- 📝 **Response Suggestions** - Generate helpful customer replies with confidence scoring
- 🎭 **Demo Generator** - Create realistic support scenarios instantly
- 📊 **Performance Tracking** - Monitor AI accuracy and agent productivity
- 🔍 **Full-Text Search** - MongoDB text indexes for fast ticket searches
- ⚡ **Real-Time Processing** - Background jobs with detailed status monitoring

![support_tickets_dashboard_with_ai_analysis](https://github.com/user-attachments/assets/ce3e8850-6647-4cd3-9b7e-0078e3216a89)

![coffee_temperature_issue_ticket_with_ai_analysis](https://github.com/user-attachments/assets/35a548fa-52a0-47ec-909f-3e710e3e6048)

![coffee_temperature_issue_ticket_with_detailed_ai_analysis](https://github.com/user-attachments/assets/e5d90f63-8640-4d4b-a86d-b6b371bba08a)

---

## Getting Started

### What You'll Need

- Ruby 3.3+ with Rails 8.0+
- MongoDB (local installation or DigitalOcean Managed)
- Node.js 18+ for CSS compilation
- A DigitalOcean account for AI services

### Setting Up DigitalOcean AI

Before installing the app, you'll need to set up your AI agent on DigitalOcean's Gradient AI platform. This takes about 10 minutes.

#### Step 1: Create a Knowledge Base

1. Follow the official DigitalOcean guide: [Create and Manage Agent Knowledge Bases](https://docs.digitalocean.com/products/gradient-ai-platform/how-to/create-manage-agent-knowledge-bases/)
2. Name: Something like `moodbrew-support-kb`

**What to use from this project:**

- Upload the documents from the `knowledge_base/` folder in this repo
- These contain MoodBrew product information, common issues, and FAQs
- You can also add your own documentation or modify the provided files

#### Step 2: Create an AI Agent

Follow the official DigitalOcean guide: [Create Agents](https://docs.digitalocean.com/products/gradient-ai-platform/how-to/create-agents/)

**Configuration tips for customer support:**

- **System Prompt** - Use this optimized prompt for support scenarios:
  ```
  You are a helpful customer support agent for MoodBrew coffee machines.
  Use the knowledge base to answer questions accurately.
  Be friendly, professional, and solution-focused.
  If you don't know something, say so honestly.
  Always prioritize customer satisfaction and safety.
  ```
- **Temperature**: 0.3 (for consistent responses)
- **Max Tokens**: 500 (appropriate for support responses)
- **Knowledge Base**: Link it to the knowledge base you created in Step 1

#### Step 3: Get Your Credentials

After creating your agent, you'll need:
- **Endpoint URL**: Found in the agent's API section (looks like `https://agent-xxx.agents.do-ai.run/api/v1/`)
- **Access Key**: Your API key (starts with `doa_v1_`)

Save these - you'll add them to your `.env` file in the installation steps below.

### Installation

**1. Get the Code**
```bash
git clone https://github.com/yourusername/sea-support.git
cd sea-support
```

**2. Install Everything**
```bash
bundle install
npm install
```

**3. Set Up Your Environment**
```bash
cp .env.example .env
```

Edit your `.env` file with your database and AI service details. The example file has helpful comments to guide you.

**4. Configure AI Services**

Add the DigitalOcean AI credentials from Step 3 above to your `.env` file:
```bash
# Replace with your actual agent credentials
DO_AGENT_ENDPOINT=https://agent-abc123.agents.do-ai.run/api/v1/
DO_AGENT_ACCESS_KEY=doa_v1_xxxxxxxxxxxx
```

The app will use these environment variables by default. (For production, you can optionally use Rails encrypted credentials instead)

**5. Set Up the Database**

For local MongoDB:
```bash
# Make sure MongoDB is running, then:
bin/rails db:mongoid:create_collections
bin/rails db:mongoid:create_indexes
bin/rails db:seed
```

For DigitalOcean Managed MongoDB, just update your `MONGODB_URI` in `.env` and run the same commands.

**6. Start Everything**

The easiest way:
```bash
bin/dev
```

This starts the Rails server and watches for CSS changes. Your app will be at `http://localhost:3000`.

For more control, run components separately:
```bash
bin/rails server          # Main app on port 3000
bundle exec sidekiq       # Background job processor
```

---

## How to Use It

### First Steps

1. **Create an account** - Sign up as a support agent
2. **Explore sample data** - The seed command loads realistic MoodBrew tickets
3. **Try the AI features** - Click "Analyze with AI" on any ticket
4. **Generate demo content** - Use the demo ticket generator for testing

### Core Features

#### Demo Ticket Generator
Perfect for testing or demonstrations:

- Go to "New Ticket" and look for the purple "Generate Demo Ticket" section
- Click the button and watch AI create realistic scenarios
- Each generation includes customer personality, problem details, and context
- Modify the generated content or generate another one
- Submit to create a real ticket you can analyze

#### AI Ticket Analysis
Transform raw support requests into actionable insights:

- Open any ticket and click "Analyze with AI"
- The system analyzes using MoodBrew knowledge context
- Review AI-generated tags, priority levels, sentiment analysis, and summaries
- Accept, modify, or reject the suggestions
- Generate suggested customer responses with confidence scoring

#### Background Job Monitoring
See what's happening behind the scenes:

- Visit `/admin/background_jobs` for detailed monitoring
- Watch AI processing in real-time
- Debug failed jobs with complete error logs
- Track processing times and success rates

### Demo Scenarios

The system comes with engaging scenarios like:

**High-Priority Emergency:**
```
"COFFEE MACHINE BROKEN - NO COFFEE FOR 3 DAYS!!!"
Customer: Mike (Very upset morning person)
AI Analysis: Priority: URGENT, Sentiment: Very Negative
Tags: [brewing-failure, mood-sensor, refund-request]
```

**Feature Request:**
```
"Feature Request: Hangover mode please! 🍷➡️☕"
Customer: Sarah (Hopeful weekend warrior)
AI Analysis: Priority: LOW, Sentiment: Positive
Tags: [feature-request, mood-profiles, weekend-mode]
```

---

## Troubleshooting AI Setup

### Common Issues and Solutions

#### Agent Not Responding
- **Check credentials**: Ensure your `DO_AGENT_ENDPOINT` and `DO_AGENT_ACCESS_KEY` are correctly copied
- **Verify endpoint URL**: It should end with `/api/v1/` (including the trailing slash)
- **Test the agent**: Use the test console in DigitalOcean to verify the agent works
- **Check quota**: Ensure you haven't exceeded your API usage limits

#### Poor Quality Responses
- **Enrich knowledge base**: Add more detailed documentation to your knowledge base
- **Adjust temperature**: Lower values (0.2-0.3) give more consistent responses
- **Refine system prompt**: Make the agent instructions more specific to your use case
- **Check model selection**: `gpt-4o` generally provides better responses than `gpt-4o-mini`

#### Knowledge Base Not Working
- **Index status**: Wait for the knowledge base to finish indexing (can take a few minutes)
- **Content format**: Ensure documents are in supported formats (text, markdown, PDF)
- **Test retrieval**: Use the knowledge base test feature to verify content is searchable
- **Agent connection**: Confirm the agent is linked to the correct knowledge base

#### Testing Your Setup
After configuration, test the AI integration:

```bash
# Run the test script
ruby scripts/test_agent_api.rb

# Or test in Rails console
bin/rails console
> service = AiService.new(true)  # Enable debug mode
> ticket = Ticket.first || Ticket.create(subject: "Test", description: "My coffee is cold")
> result = service.analyze_ticket(ticket)
> puts result
```

---

## Development

### Running Tests
```bash
bundle exec rspec                    # Full test suite
bundle exec rspec spec/models/       # Just model tests
bundle exec rspec spec/services/     # Service layer tests
```

### Code Quality
```bash
bundle exec rubocop                  # Check style
bundle exec rubocop -a               # Auto-fix issues
bundle exec brakeman                 # Security scan
```

### Database Operations
```bash
bin/rails db:mongoid:create_indexes     # Ensure performance indexes
bin/rails db:mongoid:purge              # Clear all data
bin/rails db:seed                       # Reload sample data
```

### Debugging AI Integration

The app includes comprehensive debugging tools:

```ruby
# In Rails console
service = AiService.new(true)  # Enable debug mode
result = service.analyze_ticket(Ticket.first)

# Check background job details
job = BackgroundJob.recent.first
job.processing_steps     # Step-by-step execution
job.console_logs        # Complete debug output
```

Debug endpoints for development:
- `/tickets/:id/debug_rag` - RAG response data
- `/tickets/:id/debug_progress` - Processing timing
- `/tickets/:id/debug_logs` - Complete logs

---

## Architecture

### Technology Stack

| Component | Technology | Purpose |
|-----------|------------|---------|
| **Backend** | Ruby on Rails 8 | Modern web framework with conventions |
| **Database** | MongoDB + Mongoid | Flexible document storage for AI metadata |
| **AI Services** | DigitalOcean Agent | Specialized support agent with built-in RAG |
| **Frontend** | Tailwind + Stimulus | Responsive UI with interactive features |
| **Background Jobs** | Sidekiq | Reliable AI processing with monitoring |
| **Testing** | RSpec + VCR | Comprehensive coverage with AI mocking |

### Key Architectural Decisions

**MongoDB Over PostgreSQL**: The flexible schema handles evolving AI metadata beautifully. We use embedded documents for related data like AI analysis and customer info.

**Service Object Pattern**: Business logic lives in service classes (`AiService`, `DemoTicketService`) rather than bloating models or controllers.

**Comprehensive Job Tracking**: The `BackgroundJob` model stores complete AI processing history, replacing ephemeral Redis cache for permanent data.

**Dual AI Backend**: DigitalOcean Agent is primary, with Gradient AI as fallback, showing real-world resilience patterns.

---

## Deployment

### DigitalOcean App Platform

1. **Create from GitHub:**
```bash
doctl apps create --spec .do/app.yaml
```

2. **Set environment variables in DO console:**
- `MONGODB_URI`: Your managed MongoDB connection
- `DO_AGENT_ENDPOINT`: DigitalOcean Agent API endpoint
- `DO_AGENT_ACCESS_KEY`: DigitalOcean Agent access key
- `RAILS_MASTER_KEY`: From `config/master.key`

3. **Deploy:**
```bash
doctl apps create-deployment <app-id>
```

### Docker

```bash
# Build
docker build -t sea-support .

# Run
docker run -p 3000:3000 \
  -e MONGODB_URI=your_mongo_uri \
  -e DO_AGENT_ENDPOINT=your_endpoint \
  -e DO_AGENT_ACCESS_KEY=your_key \
  sea-support
```

---

## Contributing

We'd love your help making this educational resource better!

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/amazing-addition`
3. Make your changes with tests
4. Commit with clear messages: `git commit -m "Add amazing feature"`
5. Push and open a Pull Request

### Guidelines

- **Add tests** for new features (we aim for 80%+ coverage)
- **Include educational comments** - this is a learning resource
- **Follow Rails conventions** and MongoDB best practices
- **Test AI integrations** with VCR cassettes for consistency
- **Update docs** for user-facing changes

---

## Educational Value

This isn't just a demo - it's a comprehensive learning resource with extensive `# LEARNING NOTE:` comments throughout explaining:

- **Rails Conventions**: Why we follow certain patterns and Rails doctrine
- **MongoDB Concepts**: Document modeling vs relational thinking, embedded documents, indexes
- **AI Integration**: Service patterns, error handling, fallback strategies
- **Testing Strategies**: MongoDB-specific approaches, VCR usage, factory patterns
- **Background Jobs**: Sidekiq patterns, retry strategies, monitoring

Look for `# LEARNING NOTE:` and `# BEST PRACTICE:` comments as you explore the code.

---

## Support & Community

- 🐛 **Found a bug?** [Open an issue](https://github.com/yourusername/sea-support/issues)
- 💡 **Have an idea?** [Start a discussion](https://github.com/yourusername/sea-support/discussions)
- ❓ **Need help?** Check the [documentation](CLAUDE.md) or open an issue
- 📚 **Want to learn more?** Read through the extensive code comments

---

## License

MIT License - feel free to use this for learning, teaching, or as a foundation for your own projects.

---

<div align="center">
**Built with ❤️ and ☕ to help you learn modern Rails + AI development**
