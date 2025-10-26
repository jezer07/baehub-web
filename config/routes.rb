Rails.application.routes.draw do
  devise_for :users
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

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
    resource :settings, only: %i[edit update], controller: "settings"
    resources :invitations, only: %i[create destroy]
    resources :tasks do
      patch :toggle_completion, on: :member
    end
    resources :events do
      resources :event_responses, only: [:create, :update], path: "responses"
    end
    resources :expenses do
      patch :settle, on: :member
    end
  end

  unauthenticated do
    root "home#index"
  end
end
