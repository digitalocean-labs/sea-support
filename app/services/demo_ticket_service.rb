# app/services/demo_ticket_service.rb
# LEARNING NOTE: Demo Ticket Generation Service
# Uses AI to generate realistic MoodBrew support tickets for demonstration purposes

class DemoTicketService
  class DemoError < StandardError; end

  def initialize
    # Use the same AI client configuration as AiService
    agent_key = Rails.application.credentials.dig(:digitalocean, :agent_access_key) rescue nil
    agent_key ||= ENV['DO_AGENT_ACCESS_KEY']
    agent_endpoint = ENV.fetch('DO_AGENT_ENDPOINT', nil)
    
    if agent_key.present? && agent_endpoint.present?
      @client = OpenAI::Client.new(
        access_token: agent_key,
        uri_base: agent_endpoint
      )
      @using_agent = true
    else
      # Fallback to Gradient AI
      api_key = Rails.application.credentials.dig(:digitalocean, :ai_api_key) rescue nil
      api_key ||= ENV['DO_AI_API_KEY'] || 'test-key'
      
      @client = OpenAI::Client.new(
        access_token: api_key,
        uri_base: ENV.fetch('DO_AI_ENDPOINT', 'https://inference.do-ai.run/v1')
      )
      @using_agent = false
    end
    
    Rails.logger.info "🎪 DemoTicketService initialized using #{@using_agent ? 'Agent' : 'Gradient AI'}"
  end

  # Generate a realistic demo ticket using AI
  def generate_demo_ticket
    begin
      Rails.logger.info "🎭 Generating demo ticket..."
      
      # Create prompt for realistic ticket generation
      prompt = build_demo_ticket_prompt
      
      # Call AI service to generate ticket data
      response = if @using_agent
        @client.chat(
          parameters: {
            model: "n/a",
            messages: [
              {
                role: "user",
                content: prompt
              }
            ],
            max_tokens: 800,
            temperature: 0.8 # Higher temperature for creative scenarios
          }
        )
      else
        @client.chat(
          parameters: {
            model: "llama3.3-70b-instruct",
            messages: [
              {
                role: "system",
                content: demo_system_prompt
              },
              {
                role: "user", 
                content: prompt
              }
            ],
            max_tokens: 800,
            temperature: 0.8
          }
        )
      end
      
      content = response.dig("choices", 0, "message", "content")
      Rails.logger.info "🤖 Generated demo content: #{content&.truncate(100)}..."
      
      # Parse the AI response and create ticket data
      parse_demo_response(content)
      
    rescue => e
      Rails.logger.error "Demo ticket generation failed: #{e.message}"
      
      # Fallback to static demo data if AI fails
      Rails.logger.info "🔄 Using fallback demo data"
      generate_fallback_demo_ticket
    end
  end

  private

  def build_demo_ticket_prompt
    if @using_agent
      <<~PROMPT
        Generate a realistic MoodBrew coffee machine support ticket for demonstration purposes. Make it creative but believable.

        Create a support scenario with:
        
        **CUSTOMER PROFILE:**
        - Realistic customer name and contact info
        - Account tier (free, premium, or enterprise)
        - MoodBrew model and serial number
        - Purchase/warranty details
        
        **ISSUE DETAILS:**
        - Engaging subject line
        - Detailed description of a coffee machine problem
        - Customer mood reflecting the issue severity
        - Realistic issue category and priority
        - Contact channel (email, phone, chat, etc.)
        
        **MAKE IT INTERESTING:**
        - Use creative scenarios (mood sensor comedy, coffee emergencies, etc.)
        - Reference MoodBrew features like mood detection, app connectivity
        - Include realistic technical details
        - Show customer personality in the description
        
        **MoodBrew Models:** MoodBrew Home, MoodBrew Pro, MoodBrew Office, MoodBrew Cafe
        **Issue Categories:** brewing, maintenance, connectivity, mood-sensor, other
        **Customer Moods:** happy, neutral, concerned, frustrated, angry
        
        Format your response as a realistic support ticket scenario.
      PROMPT
    else
      <<~PROMPT
        Generate realistic MoodBrew support ticket data for a demo. Be creative but believable.
        
        Include:
        - Customer name, email, phone
        - MoodBrew machine model and serial number  
        - Engaging subject line
        - Detailed issue description with customer personality
        - Appropriate priority and category
        - Customer mood reflecting the issue
        - Account tier and warranty status
        
        Make it interesting - coffee emergencies, mood sensor comedy, connectivity issues, etc.
        
        Respond with realistic support ticket content that shows the customer's voice.
      PROMPT
    end
  end

  def demo_system_prompt
    <<~SYSTEM
      You are a creative assistant that generates realistic MoodBrew coffee machine support tickets for demonstration purposes.
      
      MoodBrew Context:
      - AI-powered coffee machines that detect user mood and adjust coffee accordingly
      - Models: MoodBrew Home ($299), MoodBrew Pro ($499), MoodBrew Office ($799), MoodBrew Cafe ($1299)
      - Features: mood detection, app connectivity, custom profiles, premium subscription
      - Common issues: brewing problems, mood sensor glitches, connectivity, maintenance
      
      Create engaging, realistic scenarios that showcase different types of support issues.
      Make customers feel real with distinct personalities and communication styles.
      Include technical details that demonstrate product knowledge.
      
      Generate diverse scenarios - from coffee emergencies to happy feature requests.
    SYSTEM
  end

  def parse_demo_response(content)
    return generate_fallback_demo_ticket unless content.present?

    begin
      # Try to extract structured data from the response
      # For agent responses, parse the natural language
      ticket_data = extract_ticket_data_from_text(content)
      
      Rails.logger.info "📋 Parsed demo ticket data: #{ticket_data[:subject]&.truncate(50)}"
      ticket_data
      
    rescue => e
      Rails.logger.error "Failed to parse demo response: #{e.message}"
      generate_fallback_demo_ticket
    end
  end

  def extract_ticket_data_from_text(content)
    # Initialize with defaults
    ticket_data = {
      subject: "Demo Support Request",
      description: content,
      priority: %w[low medium high urgent].sample,
      channel: %w[email phone chat social in_person].sample,
      issue_category: %w[brewing maintenance connectivity mood-sensor other].sample,
      machine_model: %w[MoodBrew\ Home MoodBrew\ Pro MoodBrew\ Office MoodBrew\ Cafe].sample,
      customer_mood: %w[happy neutral concerned frustrated angry].sample,
      customer_info: generate_customer_info
    }

    # Try to extract specific details from content if it's structured
    if content.include?("Subject:") || content.include?("ISSUE:")
      # Extract subject line
      if match = content.match(/(?:Subject|ISSUE):\s*([^\n]+)/i)
        ticket_data[:subject] = match[1].strip
      end
      
      # Extract description from content
      description_patterns = [
        /Description:\s*(.*?)(?:\n\n|\n[A-Z]|$)/im,
        /Issue:\s*(.*?)(?:\n\n|\n[A-Z]|$)/im,
        /Problem:\s*(.*?)(?:\n\n|\n[A-Z]|$)/im
      ]
      
      description_patterns.each do |pattern|
        if match = content.match(pattern)
          description = match[1].strip
          if description.length > 50
            ticket_data[:description] = description
            break
          end
        end
      end
    end

    # Ensure description isn't too long for demo purposes
    if ticket_data[:description].length > 1000
      ticket_data[:description] = ticket_data[:description].truncate(1000)
    end

    # Extract customer mood if mentioned in content
    mood_keywords = {
      'angry' => %w[furious rage angry mad upset pissed],
      'frustrated' => %w[frustrated annoying frustrating irritated],
      'concerned' => %w[worried concerned trouble problem issue],
      'happy' => %w[love great excellent amazing wonderful fantastic],
      'neutral' => %w[please help need question]
    }

    content_lower = content.downcase
    mood_keywords.each do |mood, keywords|
      if keywords.any? { |keyword| content_lower.include?(keyword) }
        ticket_data[:customer_mood] = mood
        break
      end
    end

    # Adjust priority based on customer mood and content urgency
    if ticket_data[:customer_mood] == 'angry' || content_lower.include?('urgent') || content_lower.include?('emergency')
      ticket_data[:priority] = 'urgent'
    elsif ticket_data[:customer_mood] == 'frustrated' || content_lower.include?('asap')
      ticket_data[:priority] = 'high'  
    elsif ticket_data[:customer_mood] == 'happy' || content_lower.include?('feature request')
      ticket_data[:priority] = 'low'
    end

    ticket_data
  end

  def generate_customer_info
    # Generate realistic customer data using common names and patterns
    first_names = %w[Emma James Sarah Michael Jennifer David Jessica Chris Amanda Matt Lisa Ryan Maria Kevin Amy Daniel]
    last_names = %w[Johnson Smith Williams Brown Jones Garcia Miller Davis Rodriguez Wilson Martinez Anderson Taylor Thomas]
    
    first_name = first_names.sample
    last_name = last_names.sample
    
    {
      customer_name: "#{first_name} #{last_name}",
      email: "#{first_name.downcase}.#{last_name.downcase}#{rand(100)}@#{%w[gmail.com yahoo.com outlook.com company.com].sample}",
      phone: "+1-#{rand(900) + 100}-#{rand(900) + 100}-#{rand(9000) + 1000}",
      account_tier: %w[free premium enterprise].sample,
      moodbrew_serial: "MB#{%w[H P O C].sample}-#{Date.current.year}-#{rand(999999).to_s.rjust(6, '0')}",
      purchase_date: rand(730.days).seconds.ago.to_date, # Random date in last 2 years
      warranty_status: %w[active expired extended].sample
    }
  end

  def generate_fallback_demo_ticket
    # Static demo scenarios as fallback when AI fails
    scenarios = [
      {
        subject: "Coffee emergency! Machine thinks I'm always sad ☹️",
        description: "Hey MoodBrew team! I love my MoodBrew Pro but there's a hilarious problem - no matter what mood I'm in, it always reads me as 'deeply sad' and keeps making decaf! I'm actually super happy most mornings but apparently my face doesn't show it before coffee. Is there a way to calibrate this thing? I need my caffeine! 😄",
        priority: "high",
        customer_mood: "frustrated",
        issue_category: "mood-sensor",
        channel: "email"
      },
      {
        subject: "Feature request: Hangover mode please! 🍷➡️☕",
        description: "Hi there! I absolutely LOVE my MoodBrew Home - best purchase ever! But I have a weekend request: could you add a 'hangover mode' that automatically makes the strongest, most caffeinated coffee possible without judging my poor life choices from the night before? Right now it detects my hangover as 'illness' and suggests herbal tea. Not helpful! 😅 I'd even pay extra for this feature.",
        priority: "low", 
        customer_mood: "happy",
        issue_category: "other",
        channel: "chat"
      },
      {
        subject: "App won't connect to my MoodBrew Office",
        description: "Our office MoodBrew Cafe has been working great for 6 months, but since last week the mobile app won't connect. The machine works fine with the physical buttons, but none of us can access our custom mood profiles or see the brewing history. We've tried restarting both the machine and our phones. The WiFi connection shows as good, but the app just says 'Connection timeout' every time. This is affecting our whole team's coffee experience!",
        priority: "medium",
        customer_mood: "concerned", 
        issue_category: "connectivity",
        channel: "phone"
      },
      {
        subject: "Strange grinding noise from my MoodBrew Pro",
        description: "Hi MoodBrew support, I've noticed a weird grinding/clicking noise coming from my MoodBrew Pro when it's brewing. It started about a week ago and seems to be getting louder. The coffee still tastes fine and the mood detection works perfectly, but I'm worried something might be wrong with the internal mechanism. The machine is about 8 months old. Should I be concerned? The noise happens mostly during the grinding phase but sometimes during brewing too.",
        priority: "medium",
        customer_mood: "concerned",
        issue_category: "maintenance", 
        channel: "email"
      },
      {
        subject: "HELP! No coffee for 3 days - machine completely dead!",
        description: "THIS IS URGENT! My MoodBrew Home completely stopped working 3 days ago. No lights, no sounds, nothing! I've checked the power cable, tried different outlets, held every button combination I can think of. The machine is only 4 months old and was working perfectly. I'm going crazy without my morning mood-adjusted coffee and buying expensive coffee shop drinks every day. I need this fixed ASAP or I want a replacement sent immediately! This is not acceptable for a $299 machine!",
        priority: "urgent",
        customer_mood: "angry",
        issue_category: "brewing",
        channel: "phone"
      }
    ]

    scenario = scenarios.sample
    
    {
      subject: scenario[:subject],
      description: scenario[:description], 
      priority: scenario[:priority],
      channel: scenario[:channel],
      issue_category: scenario[:issue_category],
      machine_model: %w[MoodBrew\ Home MoodBrew\ Pro MoodBrew\ Office MoodBrew\ Cafe].sample,
      customer_mood: scenario[:customer_mood],
      customer_info: generate_customer_info
    }
  end
end