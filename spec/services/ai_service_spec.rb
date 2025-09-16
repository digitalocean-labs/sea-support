# spec/services/ai_service_spec.rb
# LEARNING NOTE: Testing AI Services with VCR and WebMock

require 'rails_helper'

RSpec.describe AiService, type: :service do
  let(:mock_client) { double('OpenAI::Client') }
  let(:ai_service) do 
    allow(OpenAI::Client).to receive(:new).and_return(mock_client)
    described_class.new
  end
  let(:ticket) { create(:ticket, :with_customer) }
  
  # LEARNING NOTE: VCR (Video Cassette Recorder) Setup
  # VCR records HTTP requests the first time and replays them in subsequent test runs
  # This ensures tests are fast and don't depend on external services
  
  describe '#analyze_ticket' do
    context 'with a valid ticket' do
      let(:ticket_with_content) do
        create(:ticket, 
          subject: 'Coffee not brewing properly',
          description: 'My MoodBrew Pro is not brewing coffee. The water reservoir is full but nothing comes out.',
          machine_model: 'MoodBrew Pro',
          issue_category: 'brewing',
          customer_mood: 'frustrated'
        )
      end
      
      # LEARNING NOTE: Mocking AI API responses for fast, reliable tests
      it 'returns AI analysis for ticket' do
        # Mock the OpenAI client response
        allow(mock_client).to receive(:completions).and_return({
          "choices" => [{
            "message" => {
              "content" => {
                "priority_suggestion" => "high",
                "tags" => ["brewing", "hardware", "urgent"],
                "sentiment" => "negative",
                "summary" => "Customer experiencing brewing failure with MoodBrew Pro",
                "suggested_actions" => ["Check water pump", "Verify power connection"],
                "confidence_score" => 0.9
              }.to_json
            }
          }]
        })
        
        result = ai_service.analyze_ticket(ticket_with_content)
        
        expect(result).to be_present
        expect(result[:tags]).to include('brewing', 'hardware', 'urgent')
        expect(result[:sentiment]).to eq('negative')
        expect(result[:confidence_score]).to eq(0.9)
      end
      
      it 'handles JSON parsing errors gracefully' do
        # Mock invalid JSON response
        allow(mock_client).to receive(:completions).and_return({
          "choices" => [{
            "message" => {
              "content" => "Invalid JSON response from AI"
            }
          }]
        })
        
        result = ai_service.analyze_ticket(ticket_with_content)
        
        expect(result).to be_present
        expect(result[:summary]).to eq('Invalid JSON response from AI')
        expect(result[:confidence_score]).to eq(0.5)
      end
    end
    
    context 'with invalid input' do
      it 'returns nil for non-ticket object' do
        result = ai_service.analyze_ticket("not a ticket")
        expect(result).to be_nil
      end
      
      it 'returns nil for nil input' do
        result = ai_service.analyze_ticket(nil)
        expect(result).to be_nil
      end
    end
    
    context 'when API errors occur' do
      before do
        allow(mock_client).to receive(:completions)
          .and_raise(Faraday::TooManyRequestsError.new("Rate limited"))
      end
      
      it 'raises RateLimitError for rate limit errors' do
        expect {
          ai_service.analyze_ticket(ticket)
        }.to raise_error(AiService::RateLimitError, /rate limited/i)
      end
    end
    
    context 'when client errors occur' do
      before do
        allow(mock_client).to receive(:completions)
          .and_raise(Faraday::ClientError.new("Client error"))
      end
      
      it 'raises ApiError for client errors' do
        expect {
          ai_service.analyze_ticket(ticket)
        }.to raise_error(AiService::ApiError, /client error/i)
      end
    end
  end
  
  describe '#generate_response' do
    let(:ticket_with_ai) { create(:ticket, :with_ai_analysis) }
    
    it 'generates customer response' do
      # Mock the OpenAI client response
      allow(mock_client).to receive(:completions).and_return({
        "choices" => [{
          "message" => {
            "content" => "Dear customer, thank you for contacting MoodBrew support. I understand your frustration..."
          }
        }]
      })
      
      result = ai_service.generate_response(ticket_with_ai)
      
      expect(result).to be_present
      expect(result).to include('Dear customer')
      expect(result).to include('MoodBrew')
    end
    
    it 'returns nil for invalid ticket' do
      result = ai_service.generate_response("invalid")
      expect(result).to be_nil
    end
    
    it 'handles API errors gracefully' do
      allow(mock_client).to receive(:completions)
        .and_raise(StandardError.new("API error"))
      
      result = ai_service.generate_response(ticket_with_ai)
      expect(result).to be_nil
    end
  end
  
  describe 'private methods' do
    # LEARNING NOTE: Testing private methods through public interface
    # Generally we don't test private methods directly, but through public methods
    
    describe 'knowledge context building' do
      let!(:relevant_kb) do
        create(:knowledge_base, 
          title: 'Brewing Issues',
          content: 'Common brewing problems and solutions for MoodBrew machines. Check water reservoir, power connections, and coffee bean levels.',
          keywords: ['brewing', 'coffee', 'water'],
          machine_models: ['MoodBrew Pro'],
          issue_types: ['brewing']
        )
      end
      
      let(:brewing_ticket) do
        create(:ticket,
          description: 'Coffee brewing problems with water flow',
          machine_model: 'MoodBrew Pro',
          issue_category: 'brewing'
        )
      end
      
      it 'includes relevant knowledge base articles in analysis' do
        # Mock successful AI response
        allow(mock_client).to receive(:completions) do |params|
          # Check that the prompt includes knowledge base context
          user_message = params[:parameters][:messages].find { |m| m[:role] == 'user' }[:content]
          expect(user_message).to include('RELEVANT KNOWLEDGE BASE')
          expect(user_message).to include('Brewing Issues')
          
          # Return mock response
          {
            "choices" => [{
              "message" => {
                "content" => {
                  "priority_suggestion" => "medium",
                  "tags" => ["brewing"],
                  "sentiment" => "neutral",
                  "summary" => "Brewing issue analysis",
                  "suggested_actions" => ["Check water flow"],
                  "confidence_score" => 0.8
                }.to_json
              }
            }]
          }
        end
        
        ai_service.analyze_ticket(brewing_ticket)
      end
    end
    
    describe 'keyword extraction' do
      it 'extracts meaningful keywords from text' do
        service = ai_service
        
        text = "My MoodBrew machine is not working properly and needs repair"
        keywords = service.send(:extract_keywords, text)
        
        expect(keywords).to include('moodbrew', 'machine', 'working', 'properly', 'needs', 'repair')
        expect(keywords).not_to include('my', 'is', 'and') # Stop words (note: 'not' is only 3 chars so passes length filter)
      end
      
      it 'handles empty text' do
        service = ai_service
        
        keywords = service.send(:extract_keywords, '')
        expect(keywords).to eq([])
        
        keywords = service.send(:extract_keywords, nil)
        expect(keywords).to eq([])
      end
    end
  end
  
  describe 'error handling' do
    it 'defines custom error classes' do
      expect(AiService::AiError).to be < StandardError
      expect(AiService::RateLimitError).to be < AiService::AiError
      expect(AiService::ApiError).to be < AiService::AiError
    end
  end
  
  # LEARNING NOTE: Integration test with actual models
  describe 'integration with ticket model' do
    let(:ticket_for_analysis) do
      create(:ticket,
        subject: 'Machine not responding',
        description: 'My MoodBrew Home is completely unresponsive',
        machine_model: 'MoodBrew Home',
        customer_mood: 'angry'
      )
    end
    
    it 'updates ticket with AI analysis results' do
      # Mock AI response
      allow(mock_client).to receive(:completions).and_return({
        "choices" => [{
          "message" => {
            "content" => {
              "priority_suggestion" => "urgent",
              "tags" => ["hardware", "unresponsive"],
              "sentiment" => "very_negative",
              "summary" => "Complete system failure requiring immediate attention",
              "suggested_actions" => ["Power cycle", "Check warranty"],
              "confidence_score" => 0.95
            }.to_json
          }
        }]
      })
      
      ai_service.analyze_ticket(ticket_for_analysis)
      ticket_for_analysis.reload
      
      expect(ticket_for_analysis.ai_analysis).to be_present
      expect(ticket_for_analysis.ai_analysis.tags).to include('hardware', 'unresponsive')
      expect(ticket_for_analysis.ai_analysis.confidence_score).to eq(0.95)
      expect(ticket_for_analysis.priority).to eq('urgent') # Auto-applied due to high confidence
    end
  end
end