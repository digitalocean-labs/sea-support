class AdvancedSearchService
  include Mongoid::Document

  # Search configuration
  SEARCH_FIELDS = %w[title description customer_email].freeze
  BOOST_FIELDS = { title: 3.0, description: 1.5, customer_email: 1.0 }.freeze
  
  class << self
    def search(query, options = {})
      return Ticket.none if query.blank?

      search_results = perform_search(query, options)
      
      # Apply post-processing
      search_results = apply_filters(search_results, options[:filters] || {})
      search_results = apply_sorting(search_results, options[:sort] || 'relevance')
      search_results = apply_pagination(search_results, options[:page] || 1, options[:per_page] || 20)

      {
        results: search_results,
        total_count: count_total_results(query, options[:filters] || {}),
        facets: generate_facets(query, options[:filters] || {}),
        suggestions: generate_suggestions(query),
        search_time: measure_search_time(query)
      }
    end

    def autocomplete(query, limit = 10)
      return [] if query.length < 2

      # Search in titles and common terms
      title_matches = Ticket.where(
        title: /#{Regexp.escape(query)}/i
      ).limit(limit).pluck(:title).uniq

      # Add common search terms
      common_terms = get_common_search_terms.select { |term| term.downcase.include?(query.downcase) }
      
      (title_matches + common_terms).uniq.first(limit)
    end

    def similar_tickets(ticket_id, limit = 5)
      ticket = Ticket.find(ticket_id)
      return [] unless ticket

      # Use AI analysis for similarity if available
      if ticket.ai_analysis&.dig('keywords')
        keywords = ticket.ai_analysis['keywords']
        similar_by_keywords(keywords, ticket_id, limit)
      else
        # Fallback to text similarity
        similar_by_text(ticket.title + ' ' + ticket.description, ticket_id, limit)
      end
    end

    def trending_searches(days = 7)
      # In production, this would analyze search logs
      cache_key = "trending_searches:#{days}"
      
      Rails.cache.fetch(cache_key, expires_in: 1.hour) do
        [
          { term: 'coffee temperature', count: 45 },
          { term: 'brewing error', count: 32 },
          { term: 'maintenance', count: 28 },
          { term: 'setup help', count: 21 },
          { term: 'warranty', count: 18 }
        ]
      end
    end

    def search_analytics(date_range = 7.days)
      {
        total_searches: calculate_total_searches(date_range),
        top_queries: get_top_queries(date_range),
        no_results_queries: get_no_results_queries(date_range),
        avg_results_per_query: calculate_avg_results(date_range),
        search_success_rate: calculate_success_rate(date_range)
      }
    end

    private

    def perform_search(query, options)
      # Tokenize and clean query
      tokens = tokenize_query(query)
      
      # Build MongoDB text search query
      search_query = build_text_search_query(tokens)
      
      # Execute search with scoring
      Ticket.where(search_query).order_by(score: { '$meta' => 'textScore' })
    end

    def tokenize_query(query)
      # Remove special characters and split into tokens
      query.gsub(/[^\w\s]/, ' ')
           .split(/\s+/)
           .reject(&:blank?)
           .map(&:downcase)
    end

    def build_text_search_query(tokens)
      # Build complex text search with phrase matching and fuzzy search
      exact_phrase = tokens.join(' ')
      fuzzy_terms = tokens.map { |token| "#{token}~" }.join(' ')
      
      {
        '$or' => [
          { '$text' => { '$search' => "\"#{exact_phrase}\"" } }, # Exact phrase (highest priority)
          { '$text' => { '$search' => tokens.join(' ') } },      # All terms
          { '$text' => { '$search' => fuzzy_terms } }            # Fuzzy matching
        ]
      }
    end

    def apply_filters(results, filters)
      filters.each do |key, value|
        next if value.blank?

        case key.to_s
        when 'status'
          results = results.where(status: value)
        when 'priority'
          results = results.where(priority: value)
        when 'category'
          results = results.where('ai_analysis.category' => value)
        when 'agent_id'
          results = results.where(assigned_agent_id: value)
        when 'date_range'
          start_date, end_date = parse_date_range(value)
          results = results.where(created_at: start_date..end_date)
        when 'has_ai_analysis'
          if value == 'true'
            results = results.where(ai_analysis: { '$exists' => true })
          else
            results = results.where(ai_analysis: { '$exists' => false })
          end
        end
      end

      results
    end

    def apply_sorting(results, sort_option)
      case sort_option.to_s
      when 'relevance'
        results # Already sorted by text score
      when 'date_desc'
        results.order_by(created_at: :desc)
      when 'date_asc'
        results.order_by(created_at: :asc)
      when 'priority'
        results.order_by(priority_order: :desc, created_at: :desc)
      when 'status'
        results.order_by(status: :asc, created_at: :desc)
      else
        results
      end
    end

    def apply_pagination(results, page, per_page)
      offset = (page - 1) * per_page
      results.skip(offset).limit(per_page)
    end

    def count_total_results(query, filters)
      search_results = perform_search(query, {})
      apply_filters(search_results, filters).count
    end

    def generate_facets(query, filters)
      base_results = perform_search(query, {})
      
      {
        status: generate_status_facets(base_results, filters),
        priority: generate_priority_facets(base_results, filters),
        category: generate_category_facets(base_results, filters),
        agent: generate_agent_facets(base_results, filters)
      }
    end

    def generate_status_facets(results, current_filters)
      temp_filters = current_filters.except('status')
      filtered_results = apply_filters(results, temp_filters)
      
      status_counts = filtered_results.group_by(&:status).transform_values(&:count)
      
      %w[open assigned in_progress resolved closed].map do |status|
        {
          value: status,
          count: status_counts[status] || 0,
          selected: current_filters['status'] == status
        }
      end
    end

    def generate_priority_facets(results, current_filters)
      temp_filters = current_filters.except('priority')
      filtered_results = apply_filters(results, temp_filters)
      
      priority_counts = filtered_results.group_by(&:priority).transform_values(&:count)
      
      %w[low medium high urgent].map do |priority|
        {
          value: priority,
          count: priority_counts[priority] || 0,
          selected: current_filters['priority'] == priority
        }
      end
    end

    def generate_category_facets(results, current_filters)
      temp_filters = current_filters.except('category')
      filtered_results = apply_filters(results, temp_filters)
      
      # Extract categories from AI analysis
      categories = filtered_results.filter_map { |t| t.ai_analysis&.dig('category') }
      category_counts = categories.group_by(&:itself).transform_values(&:count)
      
      category_counts.map do |category, count|
        {
          value: category,
          count: count,
          selected: current_filters['category'] == category
        }
      end
    end

    def generate_agent_facets(results, current_filters)
      temp_filters = current_filters.except('agent_id')
      filtered_results = apply_filters(results, temp_filters)
      
      agent_counts = filtered_results.group_by(&:assigned_agent_id).transform_values(&:count)
      agents = Agent.where(:id.in => agent_counts.keys).index_by(&:id)
      
      agent_counts.map do |agent_id, count|
        agent = agents[agent_id]
        {
          value: agent_id,
          label: agent&.name || 'Unassigned',
          count: count,
          selected: current_filters['agent_id'] == agent_id
        }
      end
    end

    def generate_suggestions(query)
      # Simple spell checking and suggestions
      suggestions = []
      
      # Check for common misspellings
      corrections = spell_check(query)
      suggestions.concat(corrections) if corrections.any?
      
      # Suggest related terms
      related_terms = find_related_terms(query)
      suggestions.concat(related_terms)
      
      suggestions.uniq.first(5)
    end

    def spell_check(query)
      # Simple implementation - in production, use a proper spell checker
      common_corrections = {
        'coffe' => 'coffee',
        'temprature' => 'temperature',
        'maintenence' => 'maintenance',
        'waranty' => 'warranty'
      }
      
      tokens = tokenize_query(query)
      corrections = []
      
      tokens.each do |token|
        if common_corrections[token]
          corrected_query = query.gsub(token, common_corrections[token])
          corrections << "Did you mean: #{corrected_query}?"
        end
      end
      
      corrections
    end

    def find_related_terms(query)
      # Find semantically related terms
      related_terms_map = {
        'coffee' => ['brewing', 'espresso', 'temperature', 'grind'],
        'temperature' => ['hot', 'cold', 'heating', 'cooling'],
        'error' => ['problem', 'issue', 'malfunction', 'bug'],
        'setup' => ['installation', 'configuration', 'getting started']
      }
      
      tokens = tokenize_query(query)
      related = []
      
      tokens.each do |token|
        if related_terms_map[token]
          related.concat(related_terms_map[token])
        end
      end
      
      related.uniq.first(3).map { |term| "Try searching for: #{term}" }
    end

    def similar_by_keywords(keywords, exclude_id, limit)
      # Find tickets with similar keywords
      Ticket.where(
        :id.ne => exclude_id,
        'ai_analysis.keywords' => { '$in' => keywords }
      ).limit(limit)
    end

    def similar_by_text(text, exclude_id, limit)
      # Use text search for similarity
      tokens = tokenize_query(text).first(5) # Use top 5 tokens
      search_query = { '$text' => { '$search' => tokens.join(' ') } }
      
      Ticket.where(search_query)
            .where(:id.ne => exclude_id)
            .order_by(score: { '$meta' => 'textScore' })
            .limit(limit)
    end

    def get_common_search_terms
      %w[
        coffee temperature brewing error maintenance setup warranty
        troubleshooting installation configuration problem issue
        hot cold heating cooling grind espresso
      ]
    end

    def parse_date_range(range_string)
      case range_string
      when 'today'
        [Time.current.beginning_of_day, Time.current.end_of_day]
      when 'week'
        [1.week.ago, Time.current]
      when 'month'
        [1.month.ago, Time.current]
      when 'year'
        [1.year.ago, Time.current]
      else
        [1.month.ago, Time.current] # Default
      end
    end

    def measure_search_time(query)
      # In production, this would measure actual search time
      rand(50..200) # Mock: 50-200ms
    end

    # Analytics methods (mock implementations)
    def calculate_total_searches(date_range)
      rand(1000..5000)
    end

    def get_top_queries(date_range)
      [
        { query: 'coffee temperature', count: 156 },
        { query: 'brewing error', count: 89 },
        { query: 'maintenance schedule', count: 67 }
      ]
    end

    def get_no_results_queries(date_range)
      [
        { query: 'purple coffee', count: 12 },
        { query: 'time travel brewing', count: 8 }
      ]
    end

    def calculate_avg_results(date_range)
      rand(5..15)
    end

    def calculate_success_rate(date_range)
      rand(85..95)
    end
  end
end
