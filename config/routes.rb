Rails.application.routes.draw do
  # LEARNING NOTE: Rails Routing for Authentication
  # Define user-friendly URLs for our authentication system
  
  # Authentication routes
  get '/login', to: 'sessions#new', as: :login
  post '/login', to: 'sessions#create'
  delete '/logout', to: 'sessions#destroy', as: :logout
  
  # Registration routes  
  get '/signup', to: 'registrations#new', as: :signup
  post '/signup', to: 'registrations#create'
  
  # Main application routes
  get '/dashboard', to: 'dashboard#index', as: :dashboard
  
  # LEARNING NOTE: RESTful Resources
  # This creates all standard CRUD routes for tickets
  # GET /tickets (index), GET /tickets/new (new), POST /tickets (create),
  # GET /tickets/:id (show), GET /tickets/:id/edit (edit), 
  # PATCH/PUT /tickets/:id (update), DELETE /tickets/:id (destroy)
  resources :tickets do
    collection do
      post :analyze_all # POST /tickets/analyze_all - Bulk AI analysis
      get :bulk_analysis_progress # GET /tickets/bulk_analysis_progress - Progress endpoint
      post :bulk_apply_responses # POST /tickets/bulk_apply_responses - Apply suggested responses to multiple tickets
      get :generate_demo_ticket # GET /tickets/generate_demo_ticket - Generate demo ticket data
    end
    member do
      post :analyze # POST /tickets/:id/analyze - AI analysis
      post :generate_response # POST /tickets/:id/generate_response - AI response generation
      post :send_ai_response # POST /tickets/:id/send_ai_response - Send AI response as message
      delete :reset_analysis # DELETE /tickets/:id/reset_analysis - Clear AI analysis
      get :ai_analysis # GET /tickets/:id/ai_analysis - Get AI analysis as JSON
      
      # Debug endpoints (development only)
      get :debug_rag # GET /tickets/:id/debug_rag - RAG response data
      get :debug_progress # GET /tickets/:id/debug_progress - Progress/timing data  
      get :debug_logs # GET /tickets/:id/debug_logs - Console logs
    end
  end
  
  # LEARNING NOTE: Root Route Strategy
  # Redirect to dashboard if logged in, login if not
  # We'll handle this logic in a custom root controller
  root 'sessions#new'
  
  # Admin routes
  namespace :admin do
    resources :background_jobs, only: [:index, :show] do
      member do
        post :retry
      end
      collection do
        post :clear_failed
      end
    end
  end
  
  # Health check for deployment monitoring
  get "up" => "rails/health#show", as: :rails_health_check

end
