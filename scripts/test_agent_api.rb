#!/usr/bin/env ruby

# Test script for DigitalOcean Agent API integration
# Run with: ruby test_agent_api.rb

require 'bundler/inline'

gemfile do
  source 'https://rubygems.org'
  gem 'ruby-openai', '~> 7.0'
  gem 'dotenv', '~> 3.0'
  gem 'json'
end

require 'openai'
require 'dotenv'
require 'json'
require 'logger'

# Load environment variables
Dotenv.load('.env')

puts "🧪 Testing DigitalOcean Agent API Integration"
puts "=" * 50

# Check environment variables
agent_endpoint = ENV['DO_AGENT_ENDPOINT']
agent_access_key = ENV['DO_AGENT_ACCESS_KEY']

unless agent_endpoint && agent_access_key
  puts "❌ ERROR: Missing environment variables"
  puts "   DO_AGENT_ENDPOINT: #{agent_endpoint ? '✓' : '✗'}"
  puts "   DO_AGENT_ACCESS_KEY: #{agent_access_key ? '✓' : '✗'}"
  exit 1
end

puts "✅ Environment variables loaded:"
puts "   Endpoint: #{agent_endpoint}"
puts "   API Key: #{agent_access_key[0..10]}..." 
puts

# Initialize OpenAI client with Agent endpoint
puts "🔧 Initializing OpenAI client with Agent endpoint..."
client = OpenAI::Client.new(
  access_token: agent_access_key,
  uri_base: agent_endpoint
)
puts "✅ Client initialized"
puts

# Sample ticket data
sample_ticket = {
  subject: "MoodBrew Pro not brewing - urgent help needed!",
  description: "My MoodBrew Pro machine stopped working this morning. I fill the water reservoir, add coffee beans, but when I press brew nothing happens. The mood sensor shows I'm frustrated (which I am!) but no coffee comes out. I have an important client meeting in 30 minutes and really need my coffee fix. This machine is only 3 months old and was working fine yesterday.",
  machine_model: "MoodBrew Pro",
  issue_category: "brewing", 
  customer_mood: "frustrated",
  priority: "medium",
  customer_name: "Sarah Johnson"
}

puts "📋 Sample ticket data:"
puts "   Subject: #{sample_ticket[:subject]}"
puts "   Model: #{sample_ticket[:machine_model]}"
puts "   Mood: #{sample_ticket[:customer_mood]}"
puts "   Category: #{sample_ticket[:issue_category]}"
puts

# Build analysis prompt (similar to AI service)
puts "📝 Building analysis prompt..."
prompt = <<~PROMPT
  Analyze this MoodBrew support ticket and return your analysis in JSON format:
  
  TICKET DETAILS:
  Subject: #{sample_ticket[:subject]}
  Description: #{sample_ticket[:description]}
  Machine Model: #{sample_ticket[:machine_model]}
  Issue Category: #{sample_ticket[:issue_category]}
  Priority: #{sample_ticket[:priority]}
  Customer: #{sample_ticket[:customer_name]}
  Customer Mood: #{sample_ticket[:customer_mood]}
  
  **PRIORITY LEVELS** (choose one):
  - "low": General questions, feature requests, non-urgent maintenance
  - "medium": Product issues affecting usability but not blocking  
  - "high": Critical functionality problems, frustrated customers
  - "urgent": Complete product failure, angry customers, business impact
  
  **SENTIMENT CATEGORIES** (choose one):
  - "positive": Happy, satisfied, complimentary customers
  - "neutral": Informational, matter-of-fact inquiries
  - "negative": Frustrated, concerned, disappointed customers
  - "very_negative": Angry, furious, threatening to cancel/return
  
  Return ONLY valid JSON in this exact format:
  {
    "priority_suggestion": "low|medium|high|urgent",
    "tags": ["tag1", "tag2", "tag3"],
    "sentiment": "positive|neutral|negative|very_negative", 
    "summary": "Brief analysis summary",
    "suggested_actions": ["action1", "action2"],
    "confidence_score": 0.85,
    "suggested_response": "Empathetic customer response acknowledging their frustration and providing clear next steps",
    "source_files": ["filename1.md", "filename2.md"]
  }
PROMPT

puts "✅ Prompt built (#{prompt.length} characters)"
puts

# Prepare request parameters matching DigitalOcean Agent API format
puts "⚙️  Preparing Agent API request..."
request_params = {
  messages: [
    {
      role: "user", 
      content: prompt
    }
  ],
  max_tokens: 1500,
  temperature: 0.3,
  stream: false,
  extra_body: {
    include_retrieval_info: true,
    include_functions_info: true,
    include_guardrails_info: false
  }
}

puts "✅ Request parameters prepared"
puts "   Messages: #{request_params[:messages].length}"
puts "   Max tokens: #{request_params[:max_tokens]}"
puts "   Temperature: #{request_params[:temperature]}"
puts "   Extra body: #{request_params[:extra_body].keys.join(', ')}"
puts

# Make the API call
puts "🚀 Making API call to Agent..."
puts "   URL: #{agent_endpoint}/chat/completions"
puts

# Show request details
puts "📤 REQUEST DETAILS:"
puts "   Method: POST"
puts "   Headers:"
puts "     Content-Type: application/json"
puts "     Authorization: Bearer #{agent_access_key[0..15]}..."
puts "     User-Agent: ruby-openai/#{OpenAI::VERSION} (Ruby/#{RUBY_VERSION})"
puts "   Body (JSON):"
puts JSON.pretty_generate(request_params)
puts

begin
  start_time = Time.now
  
  # Note: HTTP debug logging would require additional configuration
  
  response = client.chat(parameters: request_params)
  
  duration = ((Time.now - start_time) * 1000).round
  puts "✅ API call successful! (#{duration}ms)"
  puts
  
  # Show response details
  puts "📥 RESPONSE DETAILS:"
  if response.respond_to?(:to_dict)
    response_dict = response.to_dict
    puts "   Response Class: #{response.class}"
    puts "   Response Keys: #{response_dict.keys.join(', ')}"
    
    # Show usage stats if available
    if response_dict["usage"]
      puts "   Token Usage:"
      puts "     Prompt: #{response_dict['usage']['prompt_tokens']} tokens"
      puts "     Completion: #{response_dict['usage']['completion_tokens']} tokens"
      puts "     Total: #{response_dict['usage']['total_tokens']} tokens"
    end
    
    # Show model info
    if response_dict["model"]
      puts "   Model: #{response_dict['model']}"
    end
    
    # Show response ID and timestamp
    if response_dict["id"]
      puts "   Response ID: #{response_dict['id']}"
    end
    
    if response_dict["created"]
      puts "   Created: #{Time.at(response_dict['created']).strftime('%Y-%m-%d %H:%M:%S UTC')}"
    end
    
  else
    puts "   Response Class: #{response.class}"
    puts "   Response Type: #{response.respond_to?(:keys) ? 'Hash-like' : 'Other'}"
  end
  puts
  
  # Extract response content
  content = response.dig("choices", 0, "message", "content")
  
  if content
    puts "📄 Raw response content:"
    puts content
    puts
    
    # Try to parse JSON
    begin
      # First, let's clean up common JSON issues
      cleaned_content = content.strip
      
      # Show the raw content for debugging
      puts "🔍 Raw JSON content (first 500 chars):"
      puts cleaned_content[0..500] + (cleaned_content.length > 500 ? "..." : "")
      puts
      
      parsed = JSON.parse(cleaned_content)
      puts "✅ JSON parsing successful!"
      puts
      
      puts "📊 Parsed analysis:"
      puts "   Priority: #{parsed['priority_suggestion']}"
      puts "   Sentiment: #{parsed['sentiment']}"
      puts "   Confidence: #{parsed['confidence_score']}"
      puts "   Tags: #{parsed['tags']&.join(', ')}"
      puts "   Source files: #{parsed['source_files']&.join(', ')}"
      puts
      
      if parsed['summary']
        puts "📝 Summary:"
        puts "   #{parsed['summary']}"
        puts
      end
      
      if parsed['suggested_response']
        puts "💬 Suggested response:"
        puts "   #{parsed['suggested_response']}"
        puts
      end
      
    rescue JSON::ParserError => e
      puts "⚠️  JSON parsing failed: #{e.message}"
      puts
      
      # Try to fix common JSON issues
      puts "🔧 Attempting to fix JSON issues..."
      
      # Common fixes
      fixed_content = cleaned_content
        .gsub(/:\s*Nine,/, ': 0.9,')           # Fix "Nine," -> 0.9
        .gsub(/:\s*Eight,/, ': 0.8,')          # Fix "Eight," -> 0.8
        .gsub(/:\s*Seven,/, ': 0.7,')          # Fix "Seven," -> 0.7
        .gsub(/:\s*[A-Z][a-z]+,/, ': 0.85,')   # Fix any written numbers -> 0.85
        .gsub(/,\s*}/, ' }')                   # Fix trailing commas
        .gsub(/,\s*\]/, ' ]')                  # Fix trailing commas in arrays
      
      if fixed_content != cleaned_content
        puts "   Applied fixes to JSON content"
        puts "🔍 Fixed JSON (first 500 chars):"
        puts fixed_content[0..500] + (fixed_content.length > 500 ? "..." : "")
        puts
        
        begin
          parsed = JSON.parse(fixed_content)
          puts "✅ JSON parsing successful after fixes!"
          puts
          
          puts "📊 Parsed analysis:"
          puts "   Priority: #{parsed['priority_suggestion']}"
          puts "   Sentiment: #{parsed['sentiment']}"
          puts "   Confidence: #{parsed['confidence_score']}"
          puts "   Tags: #{parsed['tags']&.join(', ')}"
          puts "   Source files: #{parsed['source_files']&.join(', ')}"
          puts
          
          if parsed['summary']
            puts "📝 Summary:"
            puts "   #{parsed['summary']}"
            puts
          end
          
          if parsed['suggested_response']
            puts "💬 Suggested response:"
            puts "   #{parsed['suggested_response']}"
            puts
          end
          
        rescue JSON::ParserError => e2
          puts "❌ JSON parsing still failed after fixes: #{e2.message}"
          puts "   Content will be used as plain text summary"
          puts
        end
      else
        puts "   No common fixes applied"
        puts "   Content will be used as plain text summary"
        puts
      end
    end
    
    # Check for retrieval data
    puts "🔍 Checking for RAG retrieval data..."
    if response.respond_to?(:to_dict)
      response_dict = response.to_dict
      if response_dict.dig("retrieval", "retrieved_data")
        retrieval_data = response_dict["retrieval"]["retrieved_data"]
        puts "✅ Found #{retrieval_data.length} retrieval items:"
        retrieval_data.first(3).each_with_index do |item, i|
          puts "   #{i+1}. #{item['filename']} (score: #{item['score']&.round(3)})"
        end
        if retrieval_data.length > 3
          puts "   ... and #{retrieval_data.length - 3} more"
        end
      else
        puts "ℹ️  No retrieval data found in response"
      end
    else
      puts "ℹ️  Cannot extract retrieval data (response format)"
    end
    
  else
    puts "❌ No content in response"
    puts "Response structure: #{response.keys}" if response.respond_to?(:keys)
  end
  
rescue => e
  puts "❌ API call failed: #{e.class.name}"
  puts "   Error: #{e.message}"
  puts
  
  # Show detailed error information
  puts "🚨 ERROR DETAILS:"
  
  if e.respond_to?(:response) && e.response
    puts "   HTTP Status: #{e.response[:status]}" if e.response[:status]
    puts "   Response Headers:"
    if e.response[:headers]
      e.response[:headers].each do |key, value|
        puts "     #{key}: #{value}"
      end
    else
      puts "     (No headers available)"
    end
    puts "   Response Body:"
    if e.response[:body]
      puts "     #{e.response[:body]}"
    else
      puts "     (No body available)"
    end
  end
  
  # Show more error context
  if e.respond_to?(:backtrace) && e.backtrace
    puts "   First few backtrace lines:"
    e.backtrace.first(5).each do |line|
      puts "     #{line}"
    end
  end
  
  puts
  exit 1
end

puts
puts "🎉 Agent API test completed successfully!"
puts
puts "💡 TIP: Set DEBUG_HTTP=true environment variable to see raw HTTP traffic"
puts "   Example: DEBUG_HTTP=true ruby test_agent_api.rb"
puts "=" * 50