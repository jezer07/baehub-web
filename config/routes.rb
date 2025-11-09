Rails.application.routes.draw do
  devise_for :users
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # API routes for mobile client
  namespace :api do
    namespace :v1 do
      # Authentication endpoints (no authentication required)
      post "auth/signup", to: "auth#signup"
      post "auth/login", to: "auth#login"
      post "auth/refresh", to: "auth#refresh"
      delete "auth/logout", to: "auth#logout"

      # Protected API endpoints (require authentication)
      resource :dashboard, only: [ :show ]

      resources :expenses
      resources :tasks do
        post :toggle_completion, on: :member
      end
      resources :events do
        post :respond, on: :member
      end
      resources :settlements

      # User profile and couple management
      get "users/profile", to: "users#profile"
      patch "users/profile", to: "users#update_profile"
      patch "users/password", to: "users#update_password"
      get "users/couple", to: "users#couple_info"
      post "users/couple/join", to: "users#join_couple"
      post "users/couple/create", to: "users#create_couple"
      post "users/couple/invite", to: "users#create_invitation"
    end
  end

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  authenticated :user do
    root "dashboard#show", as: :authenticated_root
    resource :dashboard, only: :show, controller: "dashboard"
    resource :pairing, only: %i[new create], controller: "pairings" do
      post :join, on: :collection
    end
    resources :invitations, only: %i[create destroy]
    resources :tasks do
      patch :toggle_completion, on: :member
    end
    resources :events do
      resources :event_responses, only: [ :create, :update ], path: "responses"
    end
    resources :expenses
    resources :settlements, only: [ :index, :new, :create, :show, :edit, :update, :destroy ]
    resource :settings, only: [ :show, :update ]
  end

  unauthenticated do
    root "home#index"
  end
end
