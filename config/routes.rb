Rails.application.routes.draw do
  root "dashboard#index"

  resources :employers, only: [ :index, :show ]
  resources :employees, only: [ :show ]
  resources :enrollments, only: [ :show ] do
    post :accept, on: :member
    post :waive, on: :member
  end
  resources :webhook_events, only: [ :show ] do
    post :replay, on: :member
  end
  resources :integration_connections, only: [ :show ] do
    post :verify_credentials, on: :member
    post :simulate_webhook, on: :member
  end

  get "workforce", to: "operations#workforce"
  get "payroll", to: "operations#payroll"
  get "benefits", to: "operations#benefits"
  get "compliance", to: "operations#compliance"
  get "integrations", to: "operations#integrations"

  resources :onboarding_tasks, only: [] do
    post :complete, on: :member
  end

  resources :time_off_requests, only: [] do
    post :approve, on: :member
    post :deny, on: :member
  end

  resources :payroll_runs, only: [ :show ] do
    post :finalize, on: :member
  end

  resources :compliance_cases, only: [] do
    post :resolve, on: :member
  end

  namespace :api do
    namespace :v1 do
      resources :employers, only: [ :create, :show ]

      namespace :webhooks do
        post "vitable", to: "vitable#create"
      end
    end
  end

  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  # root "posts#index"
end
