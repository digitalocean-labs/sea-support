# lib/tasks/mongodb.rake
# MongoDB maintenance tasks for SupportIQ

namespace :mongodb do
  desc 'Create all MongoDB indexes defined in models'
  task create_indexes: :environment do
    puts "🔧 Creating MongoDB indexes..."
    
    # Force model loading to register all indexes
    Rails.application.eager_load!
    
    # Create indexes for each model
    [Ticket, BackgroundJob, Agent].each do |model|
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
  
  desc 'List all existing indexes'
  task list_indexes: :environment do
    puts "📋 Listing MongoDB indexes..."
    
    [Ticket, BackgroundJob, Agent].each do |model|
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
  
  desc 'Drop and recreate all indexes'
  task rebuild_indexes: :environment do
    puts "🔄 Rebuilding all MongoDB indexes..."
    
    Rails.application.eager_load!
    
    [Ticket, BackgroundJob, Agent].each do |model|
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
end