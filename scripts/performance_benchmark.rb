#!/usr/bin/env ruby

require_relative '../config/environment'
require 'benchmark'

class PerformanceBenchmark
  def initialize
    @results = {}
    setup_test_data
  end

  def run_all_benchmarks
    puts "🚀 Starting Performance Benchmarks"
    puts "=" * 50

    benchmark_ticket_creation
    benchmark_search_performance
    benchmark_ai_analysis
    benchmark_analytics_queries
    benchmark_caching_performance
    benchmark_api_endpoints

    print_summary
  end

  private

  def benchmark_ticket_creation
    puts "\n📝 Benchmarking Ticket Creation"
    
    time = Benchmark.measure do
      100.times do |i|
        Ticket.create!(
          title: "Performance Test Ticket #{i}",
          description: "This is a test ticket for performance benchmarking",
          customer_email: "test#{i}@example.com",
          customer_name: "Test User #{i}",
          priority: %w[low medium high].sample,
          status: 'open'
        )
      end
    end

    @results[:ticket_creation] = {
      total_time: time.real,
      per_operation: (time.real / 100) * 1000, # ms
      operations_per_second: 100 / time.real
    }

    puts "  ✅ Created 100 tickets in #{time.real.round(3)}s"
    puts "  📊 #{@results[:ticket_creation][:per_operation].round(2)}ms per ticket"
  end

  def benchmark_search_performance
    puts "\n🔍 Benchmarking Search Performance"
    
    search_queries = [
      'coffee temperature',
      'brewing error',
      'maintenance',
      'setup help',
      'warranty issue'
    ]

    total_time = 0
    search_count = 0

    search_queries.each do |query|
      time = Benchmark.measure do
        10.times do
          AdvancedSearchService.search(query, { page: 1, per_page: 20 })
          search_count += 1
        end
      end
      total_time += time.real
    end

    @results[:search_performance] = {
      total_time: total_time,
      per_operation: (total_time / search_count) * 1000,
      operations_per_second: search_count / total_time
    }

    puts "  ✅ Performed #{search_count} searches in #{total_time.round(3)}s"
    puts "  📊 #{@results[:search_performance][:per_operation].round(2)}ms per search"
  end

  def benchmark_ai_analysis
    puts "\n🤖 Benchmarking AI Analysis"
    
    tickets = Ticket.limit(10)
    
    time = Benchmark.measure do
      tickets.each do |ticket|
        # Mock AI analysis for benchmarking
        ticket.update(
          ai_analysis: {
            category: %w[technical billing general].sample,
            priority_suggestion: %w[low medium high].sample,
            confidence_score: rand(0.5..1.0),
            keywords: %w[coffee temperature brewing error].sample(3),
            processing_time_ms: rand(100..500)
          }
        )
      end
    end

    @results[:ai_analysis] = {
      total_time: time.real,
      per_operation: (time.real / 10) * 1000,
      operations_per_second: 10 / time.real
    }

    puts "  ✅ Analyzed 10 tickets in #{time.real.round(3)}s"
    puts "  📊 #{@results[:ai_analysis][:per_operation].round(2)}ms per analysis"
  end

  def benchmark_analytics_queries
    puts "\n📊 Benchmarking Analytics Queries"
    
    queries = [
      -> { AnalyticsService.dashboard_metrics },
      -> { AnalyticsService.ticket_metrics },
      -> { AnalyticsService.ai_performance_metrics },
      -> { AnalyticsService.real_time_stats }
    ]

    total_time = 0
    query_count = 0

    queries.each do |query|
      time = Benchmark.measure do
        5.times do
          query.call
          query_count += 1
        end
      end
      total_time += time.real
    end

    @results[:analytics_queries] = {
      total_time: total_time,
      per_operation: (total_time / query_count) * 1000,
      operations_per_second: query_count / total_time
    }

    puts "  ✅ Executed #{query_count} analytics queries in #{total_time.round(3)}s"
    puts "  📊 #{@results[:analytics_queries][:per_operation].round(2)}ms per query"
  end

  def benchmark_caching_performance
    puts "\n💾 Benchmarking Caching Performance"
    
    # Test cache performance
    cache_operations = 0
    
    time = Benchmark.measure do
      100.times do |i|
        # Write to cache
        Rails.cache.write("benchmark_key_#{i}", { data: "test_data_#{i}" })
        cache_operations += 1
        
        # Read from cache
        Rails.cache.read("benchmark_key_#{i}")
        cache_operations += 1
      end
    end

    @results[:caching_performance] = {
      total_time: time.real,
      per_operation: (time.real / cache_operations) * 1000,
      operations_per_second: cache_operations / time.real
    }

    puts "  ✅ Performed #{cache_operations} cache operations in #{time.real.round(3)}s"
    puts "  📊 #{@results[:caching_performance][:per_operation].round(2)}ms per operation"
  end

  def benchmark_api_endpoints
    puts "\n🌐 Benchmarking API Endpoints"
    
    # Simulate API calls
    api_calls = 0
    
    time = Benchmark.measure do
      50.times do
        # Simulate ticket listing
        Ticket.limit(20).to_a
        api_calls += 1
        
        # Simulate ticket search
        AdvancedSearchService.search('test', { page: 1, per_page: 10 })
        api_calls += 1
      end
    end

    @results[:api_endpoints] = {
      total_time: time.real,
      per_operation: (time.real / api_calls) * 1000,
      operations_per_second: api_calls / time.real
    }

    puts "  ✅ Simulated #{api_calls} API calls in #{time.real.round(3)}s"
    puts "  📊 #{@results[:api_endpoints][:per_operation].round(2)}ms per call"
  end

  def print_summary
    puts "\n" + "=" * 50
    puts "📈 PERFORMANCE BENCHMARK SUMMARY"
    puts "=" * 50

    @results.each do |benchmark, metrics|
      puts "\n#{benchmark.to_s.humanize}:"
      puts "  Total Time: #{metrics[:total_time].round(3)}s"
      puts "  Per Operation: #{metrics[:per_operation].round(2)}ms"
      puts "  Operations/sec: #{metrics[:operations_per_second].round(2)}"
      
      # Performance rating
      rating = performance_rating(metrics[:per_operation])
      puts "  Rating: #{rating}"
    end

    puts "\n🎯 Overall Performance Score: #{calculate_overall_score}"
    puts "\n💡 Recommendations:"
    print_recommendations
  end

  def performance_rating(ms_per_operation)
    case ms_per_operation
    when 0..50
      "🟢 Excellent"
    when 51..100
      "🟡 Good"
    when 101..200
      "🟠 Fair"
    else
      "🔴 Needs Improvement"
    end
  end

  def calculate_overall_score
    total_score = 0
    @results.each do |_, metrics|
      # Score based on operations per second (higher is better)
      score = [metrics[:operations_per_second] * 10, 100].min
      total_score += score
    end
    
    average_score = total_score / @results.count
    "#{average_score.round(1)}/100"
  end

  def print_recommendations
    slow_operations = @results.select { |_, metrics| metrics[:per_operation] > 100 }
    
    if slow_operations.empty?
      puts "  ✅ All operations are performing well!"
    else
      slow_operations.each do |operation, _|
        case operation
        when :ticket_creation
          puts "  • Consider database indexing for ticket creation"
        when :search_performance
          puts "  • Implement search result caching"
        when :ai_analysis
          puts "  • Optimize AI service calls or add async processing"
        when :analytics_queries
          puts "  • Add caching layer for analytics data"
        end
      end
    end
  end

  def setup_test_data
    # Clean up any existing test data
    Ticket.where(title: /Performance Test/).delete_all
    
    # Create some base test data
    unless Agent.exists?
      Agent.create!(
        name: "Test Agent",
        email: "test@example.com",
        password: "password123",
        role: "agent"
      )
    end
  end
end

# Run benchmarks if script is executed directly
if __FILE__ == $0
  benchmark = PerformanceBenchmark.new
  benchmark.run_all_benchmarks
end
