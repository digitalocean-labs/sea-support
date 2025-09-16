module ApplicationHelper
  def markdown(text)
    return '' if text.blank?
    
    renderer = Redcarpet::Render::HTML.new(
      filter_html: true,
      no_images: true,
      no_links: false,
      no_styles: true,
      safe_links_only: true,
      with_toc_data: true,
      hard_wrap: true
    )
    
    markdown_processor = Redcarpet::Markdown.new(renderer, {
      autolink: true,
      tables: true,
      fenced_code_blocks: true,
      strikethrough: true,
      superscript: true,
      underline: true,
      quote: true,
      footnotes: true
    })
    
    markdown_processor.render(text).html_safe
  end

  # Helper method to generate CSS classes for form fields with error states
  def field_classes_with_errors(model, field_name, base_classes = "")
    base_field_classes = base_classes.presence || "w-full px-4 py-3 border rounded-lg focus:ring-2 focus:border-transparent transition-colors"
    
    if model&.errors&.[](field_name)&.present?
      # Error state: red border, red background tint, red focus ring
      "#{base_field_classes} border-red-300 bg-red-50 text-red-900 placeholder-red-400 focus:ring-red-500 focus:border-red-500"
    else
      # Normal state: default styling
      "#{base_field_classes} border-gray-300 focus:ring-amber-500"
    end
  end

  # Helper method to display field-specific error messages
  def field_error_message(model, field_name)
    return unless model&.errors&.[](field_name)&.present?
    
    error_message = model.errors[field_name].first
    content_tag :div, class: "mt-1 text-sm text-red-600 flex items-center" do
      concat content_tag(:svg, class: "w-4 h-4 mr-1 flex-shrink-0", fill: "currentColor", viewBox: "0 0 20 20") do
        content_tag :path, nil, d: "M10 18a8 8 0 100-16 8 8 0 000 16zM8.707 7.293a1 1 0 00-1.414 1.414L8.586 10l-1.293 1.293a1 1 0 101.414 1.414L10 11.414l1.293 1.293a1 1 0 001.414-1.414L11.414 10l1.293-1.293a1 1 0 00-1.414-1.414L10 8.586 8.707 7.293z"
      end
      concat error_message
    end
  end
  
  # Parse AI analysis data from either Agent markdown or Gradient JSON format
  def parse_ai_analysis(ai_analysis)
    return nil unless ai_analysis.present?
    
    result = {
      summary: nil,
      priority: nil,
      sentiment: nil,
      confidence_score: ai_analysis.confidence_score,
      tags: ai_analysis.tags || [],
      suggested_actions: []
    }
    
    # Both Agent and Gradient AI now return structured data
    if ai_analysis.summary.present?
      result[:summary] = ai_analysis.summary
      result[:priority] = ai_analysis.priority_suggestion
      result[:sentiment] = ai_analysis.sentiment
    end
    
    result
  end
  
  private
  
  def parse_agent_markdown(markdown_text)
    return {} unless markdown_text.present?
    
    parsed = {
      summary: nil,
      priority: nil,
      sentiment: nil,
      confidence_score: nil,
      tags: [],
      suggested_actions: []
    }
    
    # Extract priority (looking for patterns like "Suggested priority – **High**")
    if match = markdown_text.match(/Suggested priority[:\s–-]+\*?\*?(\w+)\*?\*?/i)
      parsed[:priority] = match[1].downcase
    elsif match = markdown_text.match(/^\d+\.\s+\*?\*?Suggested priority[^–]*\*?\*?[:\s–-]+\*?\*?(\w+)\*?\*?/im)
      parsed[:priority] = match[1].downcase
    end
    
    # Extract sentiment (looking for "Customer appears **concerned**" or similar)
    if match = markdown_text.match(/(?:Customer appears|Sentiment analysis)[:\s–-]+\*?\*?(\w+(?:\s+\w+)?)\*?\*?/i)
      sentiment_text = match[1].downcase
      # Map common sentiment descriptions to standard values
      parsed[:sentiment] = case sentiment_text
        when /very.?negative|angry|furious|rage/i then 'very_negative'
        when /negative|frustrated|upset/i then 'negative'
        when /positive|happy|pleased/i then 'positive'
        when /concerned|worried/i then 'negative'
        else 'neutral'
      end
    end
    
    # Extract confidence score (looking for "Confidence score – 0.94")
    if match = markdown_text.match(/Confidence score[:\s–-]+(\d+\.?\d*)/i)
      parsed[:confidence_score] = match[1].to_f
    elsif match = markdown_text.match(/^\d+\.\s+\*?\*?Confidence score[^–]*\*?\*?[:\s–-]+(\d+\.?\d*)/im)
      parsed[:confidence_score] = match[1].to_f
    end
    
    # Extract tags (multiple format support for Agent responses)
    if markdown_text.include?("#")
      # Hash-style tags: #tag1 #tag2
      parsed[:tags] = markdown_text.scan(/#(\w+)/).flatten.map(&:downcase).uniq
    elsif match = markdown_text.match(/Key [Tt]ags.*?\|(.+)/i)
      # Table format: | **3. Key Tags** | `error-code`, `power-outage`, `no-brew`
      tag_content = match[1]
      parsed[:tags] = tag_content.scan(/`([^`]+)`/).flatten.map(&:strip).map(&:downcase).reject(&:empty?)
    elsif match = markdown_text.match(/Key tags[:\s–-]+([^\.]+)/i)
      # Standard format: Key tags – tag1, tag2, tag3
      tag_text = match[1].gsub(/[#\*]/,'')
      parsed[:tags] = tag_text.split(/[,;]/).map(&:strip).map(&:downcase).reject(&:empty?)
    end
    
    # Extract suggested actions (looking for numbered lists after "Recommended next actions")
    if match = markdown_text.match(/Recommended next actions[:\s]+(.*?)(?:\n\n|\n\d+\.|$)/im)
      actions_text = match[1]
      # Extract step descriptions
      parsed[:suggested_actions] = actions_text.scan(/(?:Step \d+|^\d+\.)[:\s–-]+([^–\n]+)/i).flatten.map(&:strip)
    end
    
    # Create a clean summary by extracting the issue classification
    if match = markdown_text.match(/Issue classification[^–]*–\s*([^\.]+\.)/i)
      parsed[:summary] = match[1].strip
    elsif match = markdown_text.match(/^\d+\.\s+\*?\*?Issue classification[^–]*\*?\*?[:\s–-]+([^\.]+\.)/im)
      parsed[:summary] = match[1].strip
    else
      # Fallback: use first meaningful sentence
      sentences = markdown_text.split(/[\.!?]/).map(&:strip).reject(&:empty?)
      parsed[:summary] = sentences.find { |s| s.length > 20 && !s.include?("ANALYSIS") } || "AI analysis completed"
    end
    
    parsed
  end
  
  public
  
  # Convert citation markers like [[C1]] to markdown links
  def convert_citations_to_markdown_links(text, source_files)
    return text unless text.present? && source_files.present?
    
    # Replace citation markers with markdown links
    text.gsub(/\[\[C(\d+)\]\]/) do |match|
      citation_number = $1.to_i
      array_index = citation_number - 1 # Convert to 0-based index
      
      if array_index >= 0 && array_index < source_files.length
        source_file = source_files[array_index]
        # Create a clean display name and link to knowledge base
        clean_name = source_file.gsub(/\.(md|txt)$/, '').humanize
        knowledge_base_url = "/knowledge_base/#{source_file.gsub(/\.(md|txt)$/, '')}"
        "[#{clean_name}](#{knowledge_base_url})"
      else
        match # Return original if index is out of range
      end
    end
  end
  
  # Helper to get sentiment color classes
  def sentiment_color_classes(sentiment)
    case sentiment&.to_s
    when 'positive'
      'bg-green-100 text-green-800'
    when 'negative', 'concerned'
      'bg-orange-100 text-orange-800'
    when 'very_negative', 'angry', 'frustrated'
      'bg-red-100 text-red-800'
    else
      'bg-gray-100 text-gray-800'
    end
  end
  
  # Helper to get priority color classes
  def priority_color_classes(priority)
    case priority&.to_s&.downcase
    when 'urgent'
      'bg-red-100 text-red-800'
    when 'high'
      'bg-orange-100 text-orange-800'
    when 'medium'
      'bg-blue-100 text-blue-800'
    when 'low'
      'bg-gray-100 text-gray-800'
    else
      'bg-purple-100 text-purple-800'
    end
  end
  
  # Helper to get sentiment emoji
  def sentiment_emoji(sentiment)
    case sentiment&.to_s
    when 'positive'
      '😊'
    when 'negative', 'concerned'
      '😟'
    when 'very_negative', 'angry', 'frustrated'
      '😠'
    else
      '😐'
    end
  end
  
  # Helper to get CSS classes for ticket table rows based on AI analysis status
  def ai_analysis_row_classes(ticket)
    base_classes = "transition-colors duration-200"
    
    if ticket.ai_analysis.present?
      confidence_score = ticket.ai_analysis.confidence_score || 0
      has_response = ticket.ai_analysis.suggested_response.present?
      
      if has_response && confidence_score >= 0.85
        # Auto-respondable: Green tint
        "#{base_classes} bg-green-50 hover:bg-green-100 border-l-4 border-green-500"
      elsif has_response
        # Has response but lower confidence: Blue tint
        "#{base_classes} bg-blue-50 hover:bg-blue-100 border-l-4 border-blue-500"
      else
        # Analyzed but no response: Yellow tint
        "#{base_classes} bg-yellow-50 hover:bg-yellow-100 border-l-4 border-yellow-500"
      end
    else
      # Not analyzed: Default with subtle gray accent
      "#{base_classes} hover:bg-gray-50 border-l-4 border-transparent hover:border-gray-300"
    end
  end
  
  # Helper to get AI analysis status with enhanced styling
  def ai_analysis_status_display(ticket)
    return { icon: '⭕', label: 'Not Analyzed', sublabel: 'Click to analyze', color_classes: 'text-gray-500' } unless ticket.ai_analysis.present?
    
    confidence_score = ticket.ai_analysis.confidence_score || 0
    has_response = ticket.ai_analysis.suggested_response.present?
    
    if has_response && confidence_score >= 0.85
      {
        icon: '✨',
        label: 'Auto-Ready',
        sublabel: "#{(confidence_score * 100).round}% confident",
        color_classes: 'text-green-900',
        dot_color: 'bg-green-400'
      }
    elsif has_response && confidence_score >= 0.7
      {
        icon: '🤖',
        label: 'High Confidence',
        sublabel: "#{(confidence_score * 100).round}% with response",
        color_classes: 'text-blue-900',
        dot_color: 'bg-blue-400'
      }
    elsif has_response
      {
        icon: '🔍',
        label: 'Analyzed',
        sublabel: "#{(confidence_score * 100).round}% with response",
        color_classes: 'text-indigo-900',
        dot_color: 'bg-indigo-400'
      }
    elsif confidence_score > 0
      {
        icon: '⚠️',
        label: 'Low Confidence',
        sublabel: "#{(confidence_score * 100).round}% no response",
        color_classes: 'text-yellow-900',
        dot_color: 'bg-yellow-400'
      }
    else
      {
        icon: '📊',
        label: 'Analyzed',
        sublabel: 'No response generated',
        color_classes: 'text-purple-900',
        dot_color: 'bg-purple-400'
      }
    end
  end
end
