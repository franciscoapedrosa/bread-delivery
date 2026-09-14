Rails.application.routes.draw do
  get "home/index"

  devise_for :users, skip: [ :registrations ]
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  resources :users
  resources :customers do
    member do
      patch :deactivate
      patch :activate
    end
  end


  resources :route_runs, only: %i[index new create show update]
  resources :scheduled_stops, only: %i[index update] do
    member do
      patch :approve
      patch :reject
    end
  end
  resources :routes do
    resources :route_stops, only: %i[create update destroy]
  end
  resources :deliveries do
    collection do
      post :reset_week
      delete :destroy_week
    end
  end
  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  # root "posts#index"
  # app´s initial page
  authenticated :user do
    root "home#index", as: :authenticated_root
  end
  devise_scope :user do
    unauthenticated do
      root "devise/sessions#new", as: :unauthenticated_root
    end
  end

  get "root", to: "home#index", as: :root
  get "my_customers", to: "customers#my_customers", as: :my_customers
  get "up" => "rails/health#show", as: :rails_health_check
end
