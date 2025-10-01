# Contributing to Sea Support

Thank you for your interest in contributing to Sea Support! This project is designed as an educational Rails application demonstrating AI-powered customer support with MongoDB and DigitalOcean's Gradient AI. We welcome contributions that help make this a better learning resource for the community.

## Table of Contents

- [Getting Started](#getting-started)
- [Development Setup](#development-setup)
- [Development Workflow](#development-workflow)
- [Testing](#testing)
- [Pull Request Process](#pull-request-process)
- [Code Style Guidelines](#code-style-guidelines)
- [Issue Guidelines](#issue-guidelines)
- [Documentation](#documentation)
- [Community Guidelines](#community-guidelines)
- [License](#license)

## Getting Started

Before you begin contributing:

1. **Read the README.md** - Familiarize yourself with the project's purpose, features, and setup
2. **Review CLAUDE.md** - Contains detailed architectural decisions and development patterns
3. **Check existing issues** - Look for issues labeled `good first issue` or `help wanted`
4. **Comment on the issue** - Let others know you're working on it to avoid duplicate efforts
5. **Follow the Code of Conduct** - Be respectful, inclusive, and collaborative

### Prerequisites

Ensure you have the following installed:

- **Ruby 3.3+** with Rails 8.0+
- **MongoDB** (local installation or DigitalOcean Managed MongoDB)
- **Node.js 18+** for CSS compilation with Tailwind
- **Git** for version control
- **Redis** (for Sidekiq background jobs)
- **A DigitalOcean account** (for AI service integration)

## Development Setup

### 1. Fork and Clone

```bash
# Fork the repository on GitHub, then clone your fork
git clone https://github.com/your-username/sea-support.git
cd sea-support

# Add the upstream repository
git remote add upstream https://github.com/digitalocean-labs/sea-support.git
```

### 2. Install Dependencies

```bash
bundle install
npm install
```

### 3. Configure Environment

```bash
# Copy the example environment file
cp .env.example .env

# Edit .env with your configuration:
# - MongoDB connection URI
# - DigitalOcean Agent credentials
# - Optional: Gradient AI credentials for fallback
```

Follow the README.md to create your DigitalOcean knowledge base and AI Agent, then add credentials to `.env`.

### 4. Set Up the Database

```bash
# Create MongoDB collections and indexes
bin/rails db:mongoid:create_collections
bin/rails db:mongoid:create_indexes

# Load sample data
bin/rails db:seed
```

### 5. Start Development Server

```bash
# Start all services (Rails + Tailwind CSS watching)
bin/dev

# Or run components separately:
bin/rails server          # Rails app on port 3000
bundle exec sidekiq       # Background job processor
```

Visit `http://localhost:3000` to see the application running.

## Development Workflow

### Making Changes

1. **Create a feature branch**
   ```bash
   git checkout -b feature/your-feature-name
   ```

2. **Make your changes**
   - Keep models focused on data and validations
   - Use service objects for business logic (`app/services/`)
   - Follow Rails and MongoDB best practices
   - Add educational comments for complex logic

3. **Run tests and linting**
   ```bash
   bundle exec rspec              # Run tests
   bundle exec rubocop            # Check code style
   bundle exec rubocop -a         # Auto-fix style issues
   ```

4. **Commit your changes**
   ```bash
   git add .
   git commit -m "feat: Add sentiment analysis to tickets"
   ```

5. **Keep your branch updated**
   ```bash
   git fetch upstream
   git rebase upstream/main
   ```

6. **Push and create a Pull Request**
   ```bash
   git push origin feature/your-feature-name
   ```

### Commit Message Format

Follow conventional commit format:

```
<type>: <subject>

<body (optional)>
```

**Types:** `feat:`, `fix:`, `docs:`, `style:`, `refactor:`, `test:`, `chore:`

**Examples:**
```
feat: Add sentiment analysis to AI ticket processing

fix: Resolve MongoDB connection timeout in production
```

## Testing

We aim for **80%+ test coverage**. All new features should include tests.

### Running Tests

```bash
# Run all tests
bundle exec rspec

# Run specific test file
bundle exec rspec spec/models/ticket_spec.rb

# Check code style
bundle exec rubocop

# Auto-fix style issues
bundle exec rubocop -a
```

### Writing Tests

We use RSpec with Factory Bot. Here are quick examples:

```ruby
# Model test
RSpec.describe Ticket, type: :model do
  it { should validate_presence_of(:subject) }
  it { should embed_one(:ai_analysis) }
end

# Service test with AI mocking
RSpec.describe AiService do
  it 'analyzes tickets', :vcr do
    VCR.use_cassette('ai_service/analysis') do
      result = service.analyze_ticket(ticket)
      expect(result[:tags]).to be_an(Array)
    end
  end
end

# System test
RSpec.describe 'Ticket Management', type: :system do
  it 'creates a new ticket' do
    visit new_ticket_path
    fill_in 'Subject', with: 'Coffee issue'
    click_button 'Create Ticket'
    expect(page).to have_content('successfully created')
  end
end
```

### Testing Notes

- **MongoDB doesn't use SQL transactions** - Tests use database cleaner (already configured in `spec/rails_helper.rb`)
- **AI API calls are mocked with VCR** - Records API responses on first run, replays them after. Learn more at [VCR docs](https://github.com/vcr/vcr)
- **To re-record API cassettes** - Delete the file in `spec/vcr_cassettes/` and run the test again

See existing tests in `spec/` for more examples.

## Pull Request Process

### Before Submitting

Ensure your PR meets these requirements:

- ✅ All tests pass (`bundle exec rspec`)
- ✅ Code style compliant (`bundle exec rubocop`)
- ✅ No security issues (`bundle exec brakeman`)
- ✅ Documentation updated if needed
- ✅ Educational comments added for complex logic

### Creating Your PR

1. **Use a descriptive title**
   ```
   Good: "Add sentiment analysis visualization to ticket dashboard"
   Bad: "Update tickets"
   ```

2. **Describe your changes**
   ```markdown
   ## Changes
   - Added sentiment analysis display on ticket cards
   - Updated AiService to include sentiment scoring
   - Added tests for sentiment edge cases

   ## Testing
   - All specs pass
   - Manual testing with demo tickets
   - Tested with both AI backends

   ## Screenshots
   [Add screenshots for UI changes]
   ```

3. **Link related issues**
   ```
   Closes #123
   Related to #456
   ```

### Review Process

1. Automated checks run tests and linting
2. Maintainers review your code
3. Address any requested changes
4. Once approved, your PR will be merged

## Code Style Guidelines

### Rails Conventions

- **Follow Rails Way** - Use Rails conventions and patterns
- **Service objects** - For complex operations (`app/services/`)
- **Background jobs** - For slow operations like AI processing
- **RESTful routes** - Follow standard CRUD patterns

### MongoDB & Mongoid Best Practices

```ruby
# Use embedded documents for tightly coupled data
class Ticket
  include Mongoid::Document

  embeds_one :ai_analysis
  embeds_one :customer_info
end

# Define indexes explicitly for performance
class Ticket
  index({ subject: 'text', description: 'text' })
  index({ status: 1, priority: 1 })
  index({ created_at: -1 })
end

# Use field types
field :subject, type: String
field :priority, type: String, default: 'medium'
```

### Educational Comments

This project is a learning resource. Add helpful comments for complex logic:

```ruby
# LEARNING NOTE: We use embedded documents instead of separate collections
# because AI analysis data is tightly coupled to its ticket and always
# loaded together. This reduces queries and keeps related data co-located.
class Ticket
  embeds_one :ai_analysis
end
```

Use prefixes: `LEARNING NOTE:`, `BEST PRACTICE:`, `MONGODB TIP:`, `RAILS CONVENTION:`, `AI INTEGRATION:`

### Ruby Style

We follow [Rails Omakase](https://world.hey.com/dhh/the-rails-doctrine-324e67f0) with Rubocop:

```bash
bundle exec rubocop      # Check your code
bundle exec rubocop -a   # Auto-fix simple issues
```

**Key conventions:**
- Double quotes for strings
- 2-space indentation
- 120 character line length max
- Modern Ruby features (safe navigation `&.`, keyword arguments)

## Issue Guidelines

### Reporting Bugs

Include:

1. **Clear title** - Describe the issue concisely
2. **Steps to reproduce** - How to trigger the bug
3. **Expected vs actual behavior**
4. **Environment details** - Ruby/Rails/MongoDB versions, OS
5. **Error messages** - Stack traces, logs

### Requesting Features

Describe:

1. **Problem** - What problem does this solve?
2. **Proposed solution** - How should it work?
3. **Alternatives** - What other approaches did you consider?
4. **Educational value** - How does this help learners?

### Issue Labels

- `bug` - Something isn't working
- `enhancement` - New feature or improvement
- `documentation` - Documentation updates
- `good first issue` - Good for newcomers
- `help wanted` - Extra attention needed
- `ai-integration` - Related to AI services
- `mongodb` - MongoDB-specific issues

## Documentation

### When to Update Documentation

Update documentation when you:

- Add new features → Update README with usage
- Change architecture → Update CLAUDE.md
- Modify AI integration → Document endpoints/parameters
- Add environment variables → Update `.env.example`
- Change dependencies → Note breaking changes

### Documentation Style

- **Clear and concise** - Avoid unnecessary jargon
- **Code examples** - Show don't just tell
- **Educational focus** - Explain *why* not just *what*
- **Keep it current** - Outdated docs are worse than none

## Community Guidelines

### Our Values

- **Respect** - Treat everyone with kindness
- **Inclusivity** - Welcome contributors of all levels
- **Learning** - Focus on education and growth
- **Collaboration** - Work together, share knowledge
- **Quality** - Maintain high standards with helpful feedback

### Communication

- **Be patient** - Everyone is learning
- **Be constructive** - Offer solutions, not just criticism
- **Be clear** - Explain your reasoning
- **Be kind** - Code reviews are about code, not people
- **Ask questions** - No question is too basic

### Code of Conduct

We follow the [Contributor Covenant Code of Conduct](https://www.contributor-covenant.org/version/2/1/code_of_conduct/):

- Use welcoming and inclusive language
- Be respectful of differing viewpoints
- Accept constructive criticism gracefully
- Focus on what's best for the community
- Show empathy toward others

### Getting Help

- **GitHub Issues** - For bugs and feature requests
- **GitHub Discussions** - For questions
- **CLAUDE.md** - Detailed architectural documentation
- **Code comments** - Extensive educational comments in codebase

## License

By contributing to Sea Support, you agree that your contributions will be licensed under the [MIT License](LICENSE).

When you submit a pull request, you certify that:

1. You have the right to submit the work
2. You grant the project a perpetual, worldwide, non-exclusive, no-charge license
3. You understand your contribution is public

---

## Thank You!

Your contributions help make Sea Support a better learning resource for the Rails, MongoDB, and AI development community. Whether you're fixing typos, improving documentation, adding tests, or building new features - every contribution matters.

**Happy coding! ☕**

---

*Questions? Open an issue or start a discussion. We're here to help!*
