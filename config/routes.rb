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
  get "lifecycle", to: "lifecycle#show"
  post "lifecycle/events/:id/approve", to: "lifecycle#approve_event", as: :approve_lifecycle_event
  post "lifecycle/sync_batch", to: "lifecycle#generate_batch", as: :generate_lifecycle_sync_batch
  get "company/setup", to: "company_setup#show", as: :company_setup
  post "company/setup/:step_key/complete", to: "company_setup#complete_step", as: :complete_company_setup_step
  get "onboarding", to: "onboarding#show"
  get "documents", to: "employee_documents#show", as: :documents
  post "documents/request_batch", to: "employee_documents#request_batch", as: :request_document_batch
  get "time-off", to: "time_off#show", as: :time_off
  get "timesheets", to: "timesheets#show"
  post "timesheets/time_entries/:id/approve", to: "timesheets#approve_entry", as: :approve_time_entry
  post "timesheets/time_entries/:id/reject", to: "timesheets#reject_entry", as: :reject_time_entry
  post "timesheets/export", to: "timesheets#generate_export", as: :generate_time_tracking_export
  get "expenses", to: "expenses#show"
  post "expenses/reimbursement_batch", to: "expenses#generate_batch", as: :generate_expense_reimbursement_batch
  post "expenses/:id/approve", to: "expenses#approve_expense", as: :approve_expense
  get "contractors", to: "contractors#show"
  post "contractors/payments/:id/approve", to: "contractors#approve_payment", as: :approve_contractor_payment
  post "contractors/payments/batch", to: "contractors#generate_batch", as: :generate_contractor_payment_batch
  get "reports", to: "reports#show"
  post "reports/snapshot", to: "reports#generate_snapshot", as: :generate_reports_snapshot
  get "compensation", to: "compensation#show"
  post "compensation/packet", to: "compensation#generate_packet", as: :generate_compensation_packet
  get "taxes", to: "taxes#show"
  post "taxes/packet", to: "taxes#generate_packet", as: :generate_tax_filing_packet
  get "payroll", to: "operations#payroll"
  get "payroll/funding", to: "payroll_funding#show", as: :payroll_funding
  post "payroll/funding/employee_bank_accounts/:id/verify", to: "payroll_funding#verify_employee_account", as: :verify_employee_bank_account
  post "payroll/funding/batch", to: "payroll_funding#generate_batch", as: :generate_payroll_funding_batch
  get "pay-statements", to: "pay_statements#show", as: :pay_statements
  post "pay-statements/batch", to: "pay_statements#generate_batch", as: :generate_pay_statement_batch
  post "pay-statements/:id/deliver", to: "pay_statements#deliver_statement", as: :deliver_pay_statement
  get "benefits", to: "operations#benefits"
  get "benefits/eligibility", to: "benefits_eligibility#show", as: :benefits_eligibility
  post "benefits/eligibility/batch", to: "benefits_eligibility#generate_batch", as: :generate_benefits_eligibility_batch
  get "benefits/reconciliation", to: "benefits_reconciliations#show", as: :benefits_reconciliation
  post "benefits/reconciliation/:enrollment_id/resolve", to: "benefits_reconciliations#resolve", as: :resolve_benefits_reconciliation_item
  get "compliance", to: "operations#compliance"
  get "integrations", to: "operations#integrations"

  resources :onboarding_tasks, only: [] do
    post :complete, on: :member
  end

  resources :employee_documents, only: [] do
    post :verify, on: :member
  end

  resources :time_off_requests, only: [] do
    post :approve, on: :member
    post :deny, on: :member
  end

  resources :payroll_runs, only: [ :show ] do
    post :finalize, on: :member
    resource :benefits_export, only: [ :show ], controller: "payroll_benefits_exports" do
      post :generate
    end
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
