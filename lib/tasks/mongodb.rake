# lib/tasks/mongodb.rake
# MongoDB maintenance tasks for Sea Support
#
# Added tasks to build / clear / inspect backend search suggestions
# based on DB content. The suggestion store is a simple prefix -> value
# document with a score (count). This is easy to query for autocomplete:
#   db.search_suggestions.find({ prefix: "he" }).sort({ score: -1 }).limit(10)
#
# Note: This file assumes Mongoid (Mongoid.default_client) or that
# model.collection returns a Mongo::Collection compatible object.
#
# Usage:
#  rake mongodb:build_suggestions            # build suggestions from DB
#  rake mongodb:build_suggestions DRY_RUN=1  # do not write, only preview
#  rake mongodb:clear_suggestions            # remove all suggestion docs
#  rake mongodb:list_suggestions PREFIX=he   # list suggestions for a prefix
#  rake mongodb:rebuild_suggestions          # clear then build
#
require 'set'
require 'time'

namespace :mongodb do
  desc "Create all MongoDB indexes defined in models"
  task create_indexes: :environment do
    puts "🔧 Creating MongoDB indexes..."

    # Force model loading to register all indexes
    Rails.application.eager_load!

    # Create indexes for each model
    [ Ticket, BackgroundJob, Agent ].each do |model|
      puts "📝 Creating indexes for #{model.name}..."
      begin
        model.create_indexes
        puts "✅ #{model.name} indexes created successfully"
      rescue => e
        puts "❌ Error creating indexes for #{model.name}: #{e.message}"
      end
    end

    puts "🎉 Index creation completed!"
  end

  desc "List all existing indexes"
  task list_indexes: :environment do
    puts "📋 Listing MongoDB indexes..."

    [ Ticket, BackgroundJob, Agent ].each do |model|
      puts "\n#{model.name} collection indexes:"
      begin
        collection = model.collection
        indexes = collection.indexes.to_a

        if indexes.any?
          indexes.each do |index|
            puts "  - #{index['name']}: #{index['key']}"
          end
        else
          puts "  No indexes found"
        end
      rescue => e
        puts "  Error listing indexes: #{e.message}"
      end
    end
  end

  desc "Drop and recreate all indexes"
  task rebuild_indexes: :environment do
    puts "🔄 Rebuilding all MongoDB indexes..."

    Rails.application.eager_load!

    [ Ticket, BackgroundJob, Agent ].each do |model|
      puts "🔄 Rebuilding indexes for #{model.name}..."
      begin
        # Remove existing indexes (except _id)
        model.remove_indexes
        # Create indexes from model definitions
        model.create_indexes
        puts "✅ #{model.name} indexes rebuilt successfully"
      rescue => e
        puts "❌ Error rebuilding indexes for #{model.name}: #{e.message}"
      end
    end

    puts "🎉 Index rebuild completed!"
  end

  # ----------------------------
  # Search suggestion helpers
  # ----------------------------

  # A modest list of stopwords to ignore when creating suggestions
  STOPWORDS = %w[
    a an the and or of in to for on with is are as by at from it this that these those
    be been has have was were which who what when where why how
  ].to_set.freeze

  # sanitize a text fragment: downcase, remove punctuation (except spaces), normalize whitespace
  def sanitize_text(str)
    return "" if str.nil?
    str.to_s.downcase.gsub(/[^\p{Alnum}\s]/u, " ").gsub(/\s+/, " ").strip
  end

  # tokenize into words, filter out stopwords and short tokens
  def tokens_from_text(str, min_length: 2)
    s = sanitize_text(str)
    return [] if s.empty?
    s.split(" ").reject { |t| STOPWORDS.include?(t) || t.length < min_length }
  end

  # generate prefixes for a token, e.g. "help" -> ["he","hel","help"]
  # limit min_prefix_len and max_prefix_len to control number of docs
  def prefixes_for_token(token, min_prefix_len: 2, max_prefix_len: 20)
    return [] if token.nil? || token.length < min_prefix_len
    max_len = [token.length, max_prefix_len].min
    (min_prefix_len..max_len).map { |l| token[0, l] }
  end

  # generate suggestions from a phrase: words and short n-grams (2-3 words)
  def suggestion_values_from_text(str, max_phrase_words: 3)
    s = sanitize_text(str)
    return [] if s.empty?
    words = s.split(" ").reject { |w| STOPWORDS.include?(w) }
    values = Set.new

    # single words
    words.each { |w| values.add(w) if w.length >= 2 }

    # short phrases: join consecutive words up to max_phrase_words
    (2..max_phrase_words).each do |n|
      words.each_with_index do |_, i|
        break if i + n > words.length
        phrase = words[i, n].join(" ")
        values.add(phrase) if phrase.length > 0
      end
    end

    values.to_a
  end

  # obtain a Mongo collection for suggestions
  def suggestions_collection
    # Prefer Mongoid.default_client if available
    if defined?(Mongoid) && Mongoid.respond_to?(:default_client)
      Mongoid.default_client['search_suggestions']
    else
      # fallback to using a model's collection's database object
      # assumes Ticket is present and has collection method
      if defined?(Ticket) && Ticket.respond_to?(:collection)
        # Ticket.collection is a Mongo::Collection; access database via its client
        db = Ticket.collection.database
        # db is a Mongo::Database
        db['search_suggestions']
      else
        raise "No Mongo client available to create suggestions collection"
      end
    end
  end

  # ----------------------------
  # Suggestion tasks
  # ----------------------------

  desc "Build search suggestions from DB content (incremental). Use DRY_RUN=1 to preview without writing."
  task build_suggestions: :environment do
    dry_run = ENV['DRY_RUN'].to_s == '1' || ENV['DRY_RUN'].to_s.downcase == 'true'
    batch_size = (ENV['BATCH_SIZE'] || 200).to_i

    puts "🔎 Building search suggestions from DB (dry_run=#{dry_run}, batch_size=#{batch_size})"
    Rails.application.eager_load!

    coll = suggestions_collection
    puts "Using suggestions collection: #{coll.namespace}"

    # choose which fields to extract from each model; this is defensive:
    # only use fields that respond_to? in model instances.
    model_field_specs = {
      Ticket => %i[title subject tags description],
      BackgroundJob => %i[name job_class description],
      Agent => %i[name email role display_name]
    }

    # Gather enumerators for each model to avoid loading all records at once
    total_processed = 0
    start_time = Time.now

    model_field_specs.each do |model, fields|
      unless model.respond_to?(:all)
        puts "⚠️  Model #{model.name} doesn't support .all - skipping"
        next
      end

      puts "🔁 Scanning #{model.name} records..."
      # Use batches if the model supports it
      enumerator = if model.respond_to?(:batch_size) && model.respond_to?(:find_in_batches)
                     # ActiveRecord style not used here; use simple all cursor
                     model.all
                   else
                     model.all
                   end

      # Iterate cursor (Mongo driver returns enumerable)
      buffer = []
      enumerator.each do |doc|
        # For each doc, collect candidate source strings
        values = []

        fields.each do |f|
          # skip fields that don't exist on the document
          if doc.respond_to?(f) && (val = doc.send(f))
            if val.is_a?(Array)
              val.each { |v| values << v.to_s }
            else
              values << val.to_s
            end
          end
        rescue => e
          # be defensive: log and continue
          puts "  ⚠️  Error accessing #{model.name}##{f}: #{e.message}"
        end

        # Also include some model-specific fallback identification data
        if model == Agent
          begin
            values << doc.name.to_s if doc.respond_to?(:name)
            values << doc.email.to_s if doc.respond_to?(:email)
          rescue
          end
        end

        buffer << values.join(" ")

        # Process in batches to keep memory usage reasonable
        if buffer.size >= batch_size
          total_processed += process_suggestion_buffer(buffer, coll, dry_run: dry_run)
          buffer.clear
        end
      end

      # Flush remaining buffer
      unless buffer.empty?
        total_processed += process_suggestion_buffer(buffer, coll, dry_run: dry_run)
        buffer.clear
      end
    end

    duration = Time.now - start_time
    puts "✅ Suggestion build completed. Total items processed: #{total_processed} in #{duration.round(2)}s"
    puts "Tip: query with `db.search_suggestions.find({ prefix: 'he' }).sort({ score: -1 }).limit(10)`"
  end

  # Helper that takes an array of candidate strings (buffer) and updates suggestion docs
  # returns the number of prefix/value updates attempted
  def process_suggestion_buffer(buffer, coll, dry_run: false)
    updates = 0
    # we'll create a local map prefix -> value -> count for this batch to reduce DB operations
    batch_map = Hash.new { |h, k| h[k] = Hash.new(0) }

    buffer.each do |text|
      next if text.nil? || text.strip.empty?

      # derive suggestion "values" from the text: words and short phrases
      suggestion_values = suggestion_values_from_text(text, max_phrase_words: 3)

      suggestion_values.each do |value|
        # generate prefixes for the value (for quick prefix search)
        # we only create prefixes for the first token of multi-word phrase and whole phrase too
        # e.g. "help desk" -> prefixes from "help" and also full phrase "help desk" prefixes
        tokens = value.split(" ")
        # include whole phrase as a value
        pfxs = prefixes_for_token(value.gsub(" ", ""), min_prefix_len: 2) # phrase collapsed for prefix
        # also include prefixes of the first word for faster single-word type-ahead
        pfxs += prefixes_for_token(tokens.first, min_prefix_len: 2) if tokens.any?
        pfxs.uniq!

        pfxs.each do |p|
          batch_map[p][value] += 1
        end
      end
    end

    # Turn the batch_map into DB upserts
    batch_ops = []
    batch_map.each do |prefix, value_map|
      value_map.each do |value, count|
        updates += count
        unless dry_run
          # Upsert a doc { prefix:, value:, score: N }
          # We increment score by count and set updated_at
          begin
            coll.find_one_and_update(
              { 'prefix' => prefix, 'value' => value },
              { '$inc' => { 'score' => count }, '$set' => { 'updated_at' => Time.now.utc } },
              upsert: true
            )
          rescue => e
            # best-effort: log and continue
            puts "    ⚠️  DB upsert error (prefix=#{prefix}, value=#{value}): #{e.message}"
          end
        end
      end
    end

    updates
  end

  desc "Remove all search suggestion documents (CAUTION: destructive)"
  task clear_suggestions: :environment do
    puts "🧹 Clearing search suggestions collection..."
    coll = suggestions_collection
    begin
      res = coll.delete_many({})
      puts "✅ Deleted #{res.deleted_count} suggestion documents"
    rescue => e
      puts "❌ Error clearing suggestions: #{e.message}"
    end
  end

  desc "Rebuild suggestions (clear then build)"
  task rebuild_suggestions: :environment do
    Rake::Task["mongodb:clear_suggestions"].invoke
    Rake::Task["mongodb:build_suggestions"].invoke
  end

  desc "List top suggestions for a prefix (use PREFIX=xx and LIMIT=10)"
  task list_suggestions: :environment do
    prefix = (ENV['PREFIX'] || '').to_s.downcase.strip
    limit = (ENV['LIMIT'] || 10).to_i
    if prefix.empty?
      puts "Please specify PREFIX=... (e.g. rake mongodb:list_suggestions PREFIX=he)"
      next
    end

    coll = suggestions_collection
    puts "🔎 Top suggestions for prefix '#{prefix}':"
    begin
      docs = coll.find({ 'prefix' => prefix }).sort({ 'score' => -1 }).limit(limit)
      docs.each do |d|
        puts "  - #{d['value']} (score=#{d['score'] || 0})"
      end
    rescue => e
      puts "❌ Error listing suggestions: #{e.message}"
    end
  end
end
