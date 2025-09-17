# app/services/ai_service.rb
# LEARNING NOTE: AI Service Integration with DigitalOcean Gradient AI
# Uses OpenAI Ruby SDK with custom endpoint override

class AiService
  # LEARNING NOTE: Error handling for AI service failures
  class AiError < StandardError; end
  class RateLimitError < AiError; end
  class ApiError < AiError; end

  def initialize(enable_debug = false, background_job = nil)
    # LEARNING NOTE: Using OpenAI Ruby SDK with DigitalOcean Agent endpoint
    # Agent has built-in RAG capabilities and MoodBrew domain knowledge

    @debug_enabled = enable_debug || Rails.env.development?
    @background_job = background_job # MongoDB BackgroundJob for persistent storage

    # Get Agent credentials from Rails credentials or ENV
    agent_key = Rails.application.credentials.dig(:digitalocean, :agent_access_key) rescue nil
    agent_key ||= ENV["DO_AGENT_ACCESS_KEY"]
    agent_endpoint = ENV["DO_AGENT_ENDPOINT"]

    # Validate required Agent configuration
    unless agent_key.present? && agent_endpoint.present?
      raise AiError, "Agent configuration missing: DO_AGENT_ENDPOINT and DO_AGENT_ACCESS_KEY required"
    end

    # Initialize OpenAI client with Agent endpoint
    @client = OpenAI::Client.new(
      access_token: agent_key,
      uri_base: agent_endpoint
    )

    # Store Agent info in background job
    if @background_job
      @background_job.update(
        ai_endpoint: "agent",
        ai_model: "agent"
      )
    end

    debug_log "AiService initialized with DigitalOcean Agent endpoint"
  end

  # CORE METHOD: Analyze a support ticket and provide AI insights with suggested response
  def analyze_ticket(ticket, include_response = true)
    return nil unless ticket.is_a?(Ticket)

    start_time = Time.current
    ensure_background_job(ticket) # Create BackgroundJob if not provided

    # Create the analysis prompt
    debug_step("Prompt Creation", "Creating AI analysis prompt", :in_progress)
    prompt = build_analysis_prompt(ticket)
    debug_step("Prompt Creation", "Prompt created (#{prompt.length} characters)", :completed)

    begin
      debug_step("RAG Retrieval", "Calling DigitalOcean Agent API", :in_progress)
      ai_start = Time.current

      # Prepare Agent request parameters (following DigitalOcean Agent API format)
      request_params = {
        messages: [
          {
            role: "user",
            content: prompt # Agents handle system prompts internally
          }
        ],
        max_tokens: 1500,
        temperature: 0.3,
        stream: false,
        # Agent-specific parameters go in extra_body
        extra_body: {
          include_retrieval_info: true,
          include_functions_info: true,
          include_guardrails_info: false
        }
      }

      # Log detailed request information
      debug_log "📤 REQUEST DETAILS:", "INFO"
      debug_log "   Method: POST", "INFO"
      debug_log "   URL: #{@client.instance_variable_get(:@uri_base)}/chat/completions", "INFO"
      debug_log "   Headers:", "INFO"
      debug_log "     Content-Type: application/json", "INFO"
      debug_log "     Authorization: Bearer #{ENV['DO_AGENT_ACCESS_KEY']&.first(15)}...", "INFO"
      debug_log "     User-Agent: ruby-openai (Rails #{Rails.version})", "INFO"
      debug_log "   Body (JSON):", "INFO"
      debug_log "     Messages: #{request_params[:messages].length} message(s)", "INFO"
      debug_log "     Max tokens: #{request_params[:max_tokens]}", "INFO"
      debug_log "     Temperature: #{request_params[:temperature]}", "INFO"
      debug_log "     Stream: #{request_params[:stream]}", "INFO"
      debug_log "     Extra body: #{request_params[:extra_body].keys.join(', ')}", "INFO"
      debug_log "     Prompt length: #{prompt.length} characters", "INFO"

      # Store request data in BackgroundJob
      @background_job&.update(request_json: request_params)

      # Call DigitalOcean AI
      response = @client.chat(parameters: request_params)

      ai_duration = ((Time.current - ai_start) * 1000).round
      debug_step("RAG Retrieval", "AI response received", :completed, ai_duration)

      # Log detailed response information
      debug_log "📥 RESPONSE DETAILS:", "INFO"
      debug_log "   Duration: #{ai_duration}ms", "INFO"

      if response.respond_to?(:to_dict)
        response_dict = response.to_dict
        debug_log "   Response Class: #{response.class}", "INFO"
        debug_log "   Response Keys: #{response_dict.keys.join(', ')}", "INFO"

        # Show usage stats if available
        if response_dict["usage"]
          debug_log "   Token Usage:", "INFO"
          debug_log "     Prompt: #{response_dict['usage']['prompt_tokens']} tokens", "INFO"
          debug_log "     Completion: #{response_dict['usage']['completion_tokens']} tokens", "INFO"
          debug_log "     Total: #{response_dict['usage']['total_tokens']} tokens", "INFO"
        end

        # Show model info
        if response_dict["model"]
          debug_log "   Model: #{response_dict['model']}", "INFO"
        end

        # Show response ID and timestamp
        if response_dict["id"]
          debug_log "   Response ID: #{response_dict['id']}", "INFO"
        end

        if response_dict["created"]
          debug_log "   Created: #{Time.at(response_dict['created']).strftime('%Y-%m-%d %H:%M:%S UTC')}", "INFO"
        end

        # Show content preview
        content_preview = response.dig("choices", 0, "message", "content")
        if content_preview
          debug_log "   Content Preview: #{content_preview.truncate(100)}", "INFO"
          debug_log "   Content Length: #{content_preview.length} characters", "INFO"
        end

      else
        debug_log "   Response Class: #{response.class}", "INFO"
        debug_log "   Response Type: #{response.respond_to?(:keys) ? 'Hash-like' : 'Other'}", "INFO"
      end

      # Store response data in BackgroundJob
      store_response_data(response, ai_duration)

      # Parse the AI analysis
      debug_step("Response Parsing", "Parsing AI response and extracting data", :in_progress)
      parse_start = Time.current
      analysis_result = parse_ai_response(response, ticket)
      parse_duration = ((Time.current - parse_start) * 1000).round
      debug_step("Response Parsing", "Analysis parsed successfully", :completed, parse_duration)

      # Generate suggested response if requested and analysis was successful
      if include_response && analysis_result && analysis_result[:confidence_score] && analysis_result[:confidence_score] > 0.7
        debug_step("Response Generation", "Generating suggested customer response", :in_progress)
        response_start = Time.current

        begin
          suggested_response = generate_response(ticket, nil)
          if suggested_response.present?
            # Update the AI analysis with the suggested response
            if ticket.ai_analysis
              ticket.ai_analysis.update(suggested_response: suggested_response)
            end
            # Add response to our result
            analysis_result[:suggested_response] = suggested_response

            response_duration = ((Time.current - response_start) * 1000).round
            debug_step("Response Generation", "Customer response generated", :completed, response_duration)
          else
            debug_step("Response Generation", "No response generated", :completed)
          end
        rescue => e
          Rails.logger.warn "Response generation failed during analysis: #{e.message}"
          debug_step("Response Generation", "Failed: #{e.message}", :error)
          # Continue without response - analysis is still valuable
        end
      else
        debug_log "Skipping response generation (confidence too low or not requested)"
      end

      total_duration = ((Time.current - start_time) * 1000).round

      # Store final metrics and mark job completed
      if @background_job
        @background_job.mark_completed({
          total_duration_ms: total_duration,
          ai_call_duration_ms: ai_duration,
          parsing_duration_ms: parse_duration,
          confidence_score: analysis_result[:confidence_score],
          has_suggested_response: analysis_result[:suggested_response].present?
        })
      end

      debug_log "🏁 Analysis completed in #{total_duration}ms", "INFO"

      analysis_result

    rescue Faraday::TooManyRequestsError => e
      raise RateLimitError, "AI service rate limited: #{e.message}"
    rescue Faraday::ClientError, Faraday::ServerError => e
      raise ApiError, "AI service error: #{e.message}"
    rescue StandardError => e
      Rails.logger.error "Unexpected AI service error: #{e.message}"
      raise AiError, "AI analysis failed: #{e.message}"
    end
  end

  # Generate a suggested response for a support ticket
  def generate_response(ticket, additional_context = nil)
    return nil unless ticket.is_a?(Ticket)

    # Use existing AI analysis if available
    analysis = ticket.ai_analysis

    # Build response prompt
    prompt = build_response_prompt(ticket, analysis, additional_context)

    begin
      # Log response generation request
      debug_log "📤 RESPONSE GENERATION REQUEST:", "INFO"
      debug_log "   Method: POST", "INFO"
      debug_log "   URL: #{@client.instance_variable_get(:@uri_base)}/chat/completions", "INFO"
      debug_log "   Purpose: Customer response generation", "INFO"
      debug_log "   Prompt length: #{prompt.length} characters", "INFO"
      debug_log "   Max tokens: 800", "INFO"
      debug_log "   Temperature: 0.4 (more creative for customer responses)", "INFO"

      response_start = Time.current

      # Agent call for response generation (following DigitalOcean Agent API format)
      response = @client.chat(
        parameters: {
          messages: [
            {
              role: "user",
              content: prompt
            }
          ],
          max_tokens: 800,
          temperature: 0.4,
          stream: false,
          # Agent-specific parameters go in extra_body
          extra_body: {
            include_retrieval_info: true,
            include_functions_info: true,
            include_guardrails_info: false
          }
        }
      )

      response_duration = ((Time.current - response_start) * 1000).round

      # Log response generation results
      debug_log "📥 RESPONSE GENERATION RESULT:", "INFO"
      debug_log "   Duration: #{response_duration}ms", "INFO"

      content = response.dig("choices", 0, "message", "content")
      if content
        debug_log "   Generated response length: #{content.length} characters", "INFO"
        debug_log "   Response preview: #{content.truncate(100)}", "INFO"
      else
        debug_log "   No response content generated", "WARN"
      end

      # Extract the response content
      response.dig("choices", 0, "message", "content")

    rescue => e
      Rails.logger.error "Response generation failed: #{e.message}"
      nil
    end
  end

  private

  # Shared category guidelines for both AI backends
  def category_guidelines
    <<~GUIDELINES
      **PRIORITY LEVELS** (choose one):
      - "low": General questions, feature requests, non-urgent maintenance
      - "medium": Product issues affecting usability but not blocking#{'  '}
      - "high": Critical functionality problems, frustrated customers
      - "urgent": Complete product failure, angry customers, business impact

      **SENTIMENT CATEGORIES** (choose one):
      - "positive": Happy, satisfied, complimentary customers
      - "neutral": Informational, matter-of-fact inquiries
      - "negative": Frustrated, concerned, disappointed customers
      - "very_negative": Angry, furious, threatening to cancel/return

      **ISSUE TAGS** (choose 2-4 from these categories):
      Core Issues: brewing-failure, mood-sensor-malfunction, connectivity-issues, app-problems
      Maintenance: descaling-needed, cleaning-required, filter-replacement, warranty-claim
      Features: feature-request, customization-help, setup-assistance, training-needed
      Business: refund-request, cancellation, upgrade-inquiry, enterprise-support

      **CONFIDENCE SCORE GUIDANCE**:
      - 0.9-1.0: Clear technical issue with obvious solution
      - 0.7-0.9: Identifiable problem with likely solution
      - 0.5-0.7: Complex issue requiring investigation
      - 0.3-0.5: Unclear problem or missing information
      - 0.0-0.3: Cannot determine issue or solution
    GUIDELINES
  end


  def build_analysis_prompt(ticket)
    customer_name = ticket.customer_info&.customer_name || "Customer"
    customer_mood = ticket.customer_mood || "neutral"

    # Agent returns JSON format for consistent parsing
    <<~PROMPT
      Analyze this MoodBrew support ticket and return your analysis in JSON format:

      TICKET DETAILS:
      Subject: #{ticket.subject}
      Description: #{ticket.description}
      Machine Model: #{ticket.machine_model || 'Unknown'}
      Issue Category: #{ticket.issue_category || 'Unknown'}
      Priority: #{ticket.priority}
      Customer: #{customer_name}
      Customer Mood: #{customer_mood}

      **CATEGORY GUIDELINES:**
      #{category_guidelines}

      Return ONLY valid JSON in this exact format:
      {
        "priority_suggestion": "low|medium|high|urgent",
        "tags": ["tag1", "tag2", "tag3"],
        "sentiment": "positive|neutral|negative|very_negative",#{' '}
        "summary": "Brief analysis summary",
        "suggested_actions": ["action1", "action2"],
        "confidence_score": 0.85,
        "suggested_response": "Empathetic customer response acknowledging their #{customer_mood == 'neutral' ? 'concern' : customer_mood + ' mood'} and providing clear next steps",
        "source_files": ["filename1.md", "filename2.md"]
      }
    PROMPT
  end

  def build_response_prompt(ticket, analysis, additional_context)
    <<~PROMPT
      Generate a helpful, empathetic response to this MoodBrew customer support ticket:

      CUSTOMER ISSUE:
      #{ticket.description}

      CUSTOMER MOOD: #{ticket.customer_mood || 'neutral'}

      #{analysis ? "AI ANALYSIS:\n#{analysis.summary}" : ''}

      #{additional_context ? "ADDITIONAL CONTEXT:\n#{additional_context}" : ''}

      Guidelines:
      - Be empathetic and acknowledge the customer's frustration
      - Provide clear, actionable steps
      - Match the tone to the customer's mood (more patient if frustrated)
      - Reference specific MoodBrew features when relevant
      - Offer escalation if the issue is complex

      Generate a professional customer service response:
    PROMPT
  end


  def parse_ai_response(response, ticket)
    # Extract the AI response content
    content = response.dig("choices", 0, "message", "content")
    return nil unless content

    # DEBUG: Log response structure
    Rails.logger.info "🤖 AI Response Debug:"
    Rails.logger.info "  Using Agent: true"
    Rails.logger.info "  Response Class: #{response.class}"
    Rails.logger.info "  Response Methods: #{response.methods.grep(/dict|to_/).join(', ')}"

    # DEBUG: Log raw response (truncated)
    if response.respond_to?(:to_dict)
      response_dict = response.to_dict
      Rails.logger.info "  Raw Response Keys: #{response_dict.keys}"
      Rails.logger.info "  Full Response: #{response_dict.to_json}"
    elsif response.is_a?(Hash)
      Rails.logger.info "  Response is Hash with keys: #{response.keys}"
      Rails.logger.info "  Full Response: #{response.to_json}"
      response_dict = response # Use hash directly
    else
      Rails.logger.info "  Response inspect: #{response.inspect}"
    end

    # Extract retrieval data from Agent response
    retrieval_data = []
    source_files = []
    Rails.logger.info "🔍 Extracting retrieval data from Agent response..."

    # Get response_dict from the response (either from to_dict or direct hash)
    response_dict = nil
    if response.respond_to?(:to_dict)
      response_dict = response.to_dict
    elsif response.is_a?(Hash)
      response_dict = response
    end

    if response_dict
      Rails.logger.info "  Response dict keys: #{response_dict.keys}"

      if response_dict["retrieval"]
        Rails.logger.info "  Found retrieval section: #{response_dict['retrieval']}"
        if response_dict["retrieval"]["retrieved_data"]
          retrieval_data = response_dict["retrieval"]["retrieved_data"]
          source_files = retrieval_data.map { |item| item["filename"] }.compact.uniq
          Rails.logger.info "  Extracted #{retrieval_data.length} retrieval items"
          Rails.logger.info "  Source files: #{source_files}"
        else
          Rails.logger.info "  No retrieved_data in retrieval section"
        end
      else
        Rails.logger.info "  No retrieval section found in response"
        Rails.logger.info "  Available sections: #{response_dict.keys}"
      end
    else
      Rails.logger.info "  Could not extract response_dict"
    end

    begin
      # Parse Agent JSON response
      parsed = JSON.parse(content)

      # Extract source files from JSON or retrieval data
      source_files_from_json = parsed["source_files"] || []
      combined_source_files = (source_files + source_files_from_json).uniq

      analysis_data = {
        tags: parsed["tags"] || [],
        summary: parsed["summary"],
        sentiment: parsed["sentiment"],
        priority_suggestion: parsed["priority_suggestion"],
        suggested_response: parsed["suggested_response"],
        confidence_score: parsed["confidence_score"]&.to_f,
        suggested_actions: parsed["suggested_actions"] || [],
        processed_at: Time.current,
        processing_time_ms: 0,
        source_files: combined_source_files
      }

      # Store detailed retrieval data in BackgroundJob if available
      if @background_job && retrieval_data.any?
        @background_job.update(rag_retrieval_data: retrieval_data)
        debug_log "Stored #{retrieval_data.length} retrieval items in BackgroundJob"
      end

      # DEBUG: Log what we're about to save
      Rails.logger.info "💾 Saving analysis data:"
      Rails.logger.info "  Summary: #{analysis_data[:summary]&.truncate(50)}"
      Rails.logger.info "  Confidence: #{analysis_data[:confidence_score]}"
      Rails.logger.info "  Source files: #{analysis_data[:source_files]}"

      # Apply the analysis to the ticket
      ticket.apply_ai_suggestions(analysis_data)

      # DEBUG: Verify what was actually saved
      if ticket.ai_analysis&.reload
        Rails.logger.info "✅ Saved to database:"
        Rails.logger.info "  Source files in DB: #{ticket.ai_analysis.source_files}"
      end

      analysis_data
    rescue JSON::ParserError => e
      Rails.logger.error "Failed to parse AI response: #{e.message}"
      Rails.logger.error "Raw response: #{content}"

      # Try to fix common JSON issues from Agent responses
      debug_log "Attempting to fix JSON parsing issues...", "WARN"

      fixed_content = content.strip
        .gsub(/:\s*Nine,/, ": 0.9,")           # Fix "Nine," -> 0.9
        .gsub(/:\s*Eight,/, ": 0.8,")          # Fix "Eight," -> 0.8
        .gsub(/:\s*Seven,/, ": 0.7,")          # Fix "Seven," -> 0.7
        .gsub(/:\s*Six,/, ": 0.6,")            # Fix "Six," -> 0.6
        .gsub(/:\s*Five,/, ": 0.5,")           # Fix "Five," -> 0.5
        .gsub(/:\s*[A-Z][a-z]+,/, ": 0.85,")   # Fix any other written numbers -> 0.85
        .gsub(/,\s*}/, " }")                   # Fix trailing commas in objects
        .gsub(/,\s*\]/, " ]")                  # Fix trailing commas in arrays

      if fixed_content != content.strip
        debug_log "Applied JSON fixes, retrying parse...", "INFO"

        begin
          parsed = JSON.parse(fixed_content)
          debug_log "JSON parsing successful after fixes!", "INFO"

          # Extract source files from JSON or retrieval data
          source_files_from_json = parsed["source_files"] || []
          combined_source_files = (source_files + source_files_from_json).uniq

          analysis_data = {
            tags: parsed["tags"] || [],
            summary: parsed["summary"],
            sentiment: parsed["sentiment"],
            priority_suggestion: parsed["priority_suggestion"],
            suggested_response: parsed["suggested_response"],
            confidence_score: parsed["confidence_score"]&.to_f,
            suggested_actions: parsed["suggested_actions"] || [],
            processed_at: Time.current,
            processing_time_ms: 0,
            source_files: combined_source_files
          }

          # Store detailed retrieval data in BackgroundJob if available
          if @background_job && retrieval_data.any?
            @background_job.update(rag_retrieval_data: retrieval_data)
            debug_log "Stored #{retrieval_data.length} retrieval items in BackgroundJob"
          end

          # Apply the analysis to the ticket
          ticket.apply_ai_suggestions(analysis_data)

          return analysis_data

        rescue JSON::ParserError => e2
          Rails.logger.error "JSON parsing still failed after fixes: #{e2.message}"
          debug_log "JSON fixes didn't work, using fallback", "ERROR"
        end
      end

      # Fallback: create basic analysis with retrieval data if available
      fallback_data = {
        summary: content.truncate(500),
        confidence_score: 0.5,
        processed_at: Time.current
      }

      # Include retrieval data in fallback if available
      if retrieval_data.any?
        fallback_data[:retrieval_data] = retrieval_data
        fallback_data[:source_files] = source_files
      end

      fallback_data
    end
  end


  # MongoDB-based debug helper methods (replaces Redis cache)
  def ensure_background_job(ticket)
    return if @background_job

    @background_job = BackgroundJob.create!(
      ticket: ticket,
      job_type: "ai_analysis",
      status: "processing",
      processing_steps: [],
      console_logs: []
    )

    debug_log "🐛 BackgroundJob created for ticket #{ticket.ticket_number}"
  end

  def debug_step(name, description, status = :in_progress, duration_ms = nil)
    return unless @debug_enabled || @background_job

    status_emoji = {
      in_progress: "⏳",
      completed: "✅",
      error: "❌"
    }[status] || "📋"

    debug_log "#{status_emoji} #{name}: #{description}#{duration_ms ? " (#{duration_ms}ms)" : ''}"

    # Store in BackgroundJob for persistent tracking
    if @background_job
      @background_job.add_processing_step(name, description, status, duration_ms)
    end
  end

  def debug_log(message, level = "DEBUG")
    return unless @debug_enabled || @background_job

    # Log to Rails logger (for log files)
    case level
    when "ERROR"
      Rails.logger.error "🐛 AiService: #{message}"
    when "WARN"
      Rails.logger.warn "🐛 AiService: #{message}"
    when "INFO"
      Rails.logger.info "🐛 AiService: #{message}"
    else
      Rails.logger.debug "🐛 AiService: #{message}"
    end

    # ALSO output to console when debug is enabled (like test script)
    if @debug_enabled
      puts "🐛 AiService: #{message}"
    end

    # Store in BackgroundJob for persistent logging
    if @background_job
      @background_job.add_console_log(message, level)
    end
  end

  def store_response_data(response, ai_duration)
    return unless @background_job

    # Store the complete AI response in BackgroundJob
    response_data = if response.respond_to?(:to_dict)
      response.to_dict
    elsif response.is_a?(Hash)
      response
    else
      { raw_response: response.inspect }
    end

    # Extract RAG retrieval data if available from Agent responses
    retrieval_data = []
    if response_data.dig("retrieval_results")
      retrieval_data = response_data["retrieval_results"]
    end

    # Update BackgroundJob with response data and timing
    @background_job.update(
      response_json: response_data,
      ai_call_duration_ms: ai_duration,
      rag_retrieval_data: retrieval_data
    )

    debug_log "Response data stored in BackgroundJob (#{response_data.to_json.length} bytes, #{ai_duration}ms)"
  end

  def store_debug_response(ticket, response)
    return unless @debug_enabled

    # Store the raw response for debugging
    response_data = if response.respond_to?(:to_dict)
      response.to_dict
    elsif response.is_a?(Hash)
      response
    else
      { raw_response: response.inspect }
    end

    debug_data = {
      raw_response: response_data,
      response_size: response_data.to_json.length,
      captured_at: Time.current
    }

    # CACHING STRATEGY: Use Redis for temporary debug data (1 hour TTL)
    # Permanent analysis results are stored in BackgroundJob model (MongoDB)
    Rails.cache.write("debug_rag_#{ticket.id}", debug_data, expires_in: 1.hour)
    debug_log "RAG response stored (#{debug_data[:response_size]} bytes)"
  end

  def finalize_debug_session(ticket, total_duration_ms)
    return unless @debug_enabled

    @debug_data[:total_duration_ms] = total_duration_ms
    @debug_data[:completed_at] = Time.current
    @debug_data[:status] = "completed"

    # Store temporary debug session data in Redis cache
    Rails.cache.write("debug_session_#{ticket.id}", @debug_data, expires_in: 1.hour)
    debug_log "🏁 Debug session completed in #{total_duration_ms}ms", "INFO"
  end

  # Public method to get debug data for a ticket
  def self.get_debug_data(ticket_id)
    {
      session: Rails.cache.read("debug_session_#{ticket_id}"),
      rag_response: Rails.cache.read("debug_rag_#{ticket_id}")
    }
  end
end
