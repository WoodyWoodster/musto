# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_07_03_230000) do
  create_table "api_request_logs", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "duration_ms"
    t.string "error_class"
    t.text "error_message"
    t.integer "integration_connection_id", null: false
    t.string "method", null: false
    t.string "operation", null: false
    t.string "path", null: false
    t.json "request_body", default: {}, null: false
    t.json "response_body", default: {}, null: false
    t.integer "status_code"
    t.datetime "updated_at", null: false
    t.index ["integration_connection_id", "operation", "created_at"], name: "idx_api_request_logs_on_connection_operation_created"
    t.index ["integration_connection_id"], name: "index_api_request_logs_on_integration_connection_id"
    t.index ["status_code"], name: "index_api_request_logs_on_status_code"
  end

  create_table "benefit_invoice_lines", force: :cascade do |t|
    t.integer "amount_cents", default: 0, null: false
    t.integer "benefit_invoice_id", null: false
    t.integer "benefit_plan_id", null: false
    t.string "coverage_level", null: false
    t.datetime "created_at", null: false
    t.integer "employee_contribution_cents", default: 0, null: false
    t.integer "employee_id", null: false
    t.integer "employer_contribution_cents", default: 0, null: false
    t.integer "enrollment_id"
    t.integer "expected_payroll_deduction_cents", default: 0, null: false
    t.integer "expected_premium_cents", default: 0, null: false
    t.json "metadata", default: {}, null: false
    t.string "status", default: "matched", null: false
    t.datetime "updated_at", null: false
    t.integer "variance_cents", default: 0, null: false
    t.index ["benefit_invoice_id", "status"], name: "index_benefit_invoice_lines_on_benefit_invoice_id_and_status"
    t.index ["benefit_invoice_id"], name: "index_benefit_invoice_lines_on_benefit_invoice_id"
    t.index ["benefit_plan_id"], name: "index_benefit_invoice_lines_on_benefit_plan_id"
    t.index ["employee_id", "benefit_plan_id"], name: "index_benefit_invoice_lines_on_employee_id_and_benefit_plan_id"
    t.index ["employee_id"], name: "index_benefit_invoice_lines_on_employee_id"
    t.index ["enrollment_id"], name: "index_benefit_invoice_lines_on_enrollment_id"
    t.index ["variance_cents"], name: "index_benefit_invoice_lines_on_variance_cents"
  end

  create_table "benefit_invoices", force: :cascade do |t|
    t.datetime "approved_at"
    t.string "carrier", null: false
    t.datetime "created_at", null: false
    t.date "due_on", null: false
    t.integer "employee_contribution_cents", default: 0, null: false
    t.integer "employer_contribution_cents", default: 0, null: false
    t.integer "employer_id", null: false
    t.string "invoice_number", null: false
    t.json "metadata", default: {}, null: false
    t.datetime "paid_at"
    t.date "period_end_on", null: false
    t.date "period_start_on", null: false
    t.string "status", default: "draft", null: false
    t.integer "total_premium_cents", default: 0, null: false
    t.datetime "updated_at", null: false
    t.integer "variance_cents", default: 0, null: false
    t.index ["carrier", "period_start_on"], name: "index_benefit_invoices_on_carrier_and_period_start_on"
    t.index ["employer_id", "invoice_number"], name: "index_benefit_invoices_on_employer_id_and_invoice_number", unique: true
    t.index ["employer_id"], name: "index_benefit_invoices_on_employer_id"
    t.index ["status", "due_on"], name: "index_benefit_invoices_on_status_and_due_on"
  end

  create_table "benefit_plans", force: :cascade do |t|
    t.string "carrier"
    t.string "category", null: false
    t.datetime "created_at", null: false
    t.integer "employer_id", null: false
    t.json "metadata", default: {}, null: false
    t.integer "monthly_premium_cents", default: 0, null: false
    t.string "name", null: false
    t.string "status", default: "available", null: false
    t.datetime "updated_at", null: false
    t.string "vitable_id"
    t.index ["employer_id", "category"], name: "index_benefit_plans_on_employer_id_and_category"
    t.index ["employer_id", "status"], name: "index_benefit_plans_on_employer_id_and_status"
    t.index ["employer_id", "vitable_id"], name: "index_benefit_plans_on_employer_id_and_vitable_id", unique: true
    t.index ["employer_id"], name: "index_benefit_plans_on_employer_id"
  end

  create_table "candidates", force: :cascade do |t|
    t.datetime "accepted_at"
    t.date "applied_on", null: false
    t.integer "compensation_cents", default: 0, null: false
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.integer "employee_id"
    t.string "first_name", null: false
    t.datetime "hired_at"
    t.integer "job_opening_id", null: false
    t.string "last_name", null: false
    t.json "metadata", default: {}, null: false
    t.datetime "offer_sent_at"
    t.string "phone"
    t.datetime "rejected_at"
    t.integer "score", default: 0, null: false
    t.string "source", default: "direct", null: false
    t.string "stage", default: "applied", null: false
    t.date "target_start_on"
    t.datetime "updated_at", null: false
    t.index ["employee_id"], name: "index_candidates_on_employee_id"
    t.index ["job_opening_id", "email"], name: "index_candidates_on_job_opening_id_and_email", unique: true
    t.index ["job_opening_id"], name: "index_candidates_on_job_opening_id"
    t.index ["stage", "applied_on"], name: "index_candidates_on_stage_and_applied_on"
  end

  create_table "compensation_changes", force: :cascade do |t|
    t.datetime "applied_at"
    t.string "applied_by"
    t.datetime "approved_at"
    t.string "approved_by"
    t.string "change_type", null: false
    t.datetime "created_at", null: false
    t.integer "current_compensation_cents", default: 0, null: false
    t.integer "delta_cents", default: 0, null: false
    t.date "effective_on", null: false
    t.integer "employee_id", null: false
    t.integer "employer_id", null: false
    t.json "metadata", default: {}, null: false
    t.integer "payroll_run_id"
    t.integer "proposed_compensation_cents", default: 0, null: false
    t.string "reason", null: false
    t.datetime "rejected_at"
    t.string "rejected_by"
    t.string "rejection_reason"
    t.string "status", default: "draft", null: false
    t.datetime "submitted_at"
    t.string "submitted_by"
    t.datetime "updated_at", null: false
    t.index ["employee_id", "effective_on"], name: "index_compensation_changes_on_employee_id_and_effective_on"
    t.index ["employee_id"], name: "index_compensation_changes_on_employee_id"
    t.index ["employer_id", "status"], name: "index_compensation_changes_on_employer_id_and_status"
    t.index ["employer_id"], name: "index_compensation_changes_on_employer_id"
    t.index ["payroll_run_id"], name: "index_compensation_changes_on_payroll_run_id"
    t.index ["status", "effective_on"], name: "index_compensation_changes_on_status_and_effective_on"
  end

  create_table "compliance_cases", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.date "due_on"
    t.integer "employee_id"
    t.integer "employer_id", null: false
    t.string "kind", null: false
    t.json "metadata", default: {}, null: false
    t.datetime "resolved_at"
    t.string "severity", default: "medium", null: false
    t.string "status", default: "open", null: false
    t.datetime "updated_at", null: false
    t.index ["employee_id"], name: "index_compliance_cases_on_employee_id"
    t.index ["employer_id", "status"], name: "index_compliance_cases_on_employer_id_and_status"
    t.index ["employer_id"], name: "index_compliance_cases_on_employer_id"
    t.index ["severity", "due_on"], name: "index_compliance_cases_on_severity_and_due_on"
  end

  create_table "contractor_payments", force: :cascade do |t|
    t.integer "amount_cents", default: 0, null: false
    t.datetime "approved_at"
    t.integer "contractor_id", null: false
    t.datetime "created_at", null: false
    t.string "description", null: false
    t.json "metadata", default: {}, null: false
    t.datetime "paid_at"
    t.date "pay_date", null: false
    t.string "payment_method", default: "ach", null: false
    t.datetime "scheduled_at"
    t.string "status", default: "draft", null: false
    t.datetime "updated_at", null: false
    t.date "work_period_end_on", null: false
    t.date "work_period_start_on", null: false
    t.index ["contractor_id", "pay_date"], name: "index_contractor_payments_on_contractor_id_and_pay_date"
    t.index ["contractor_id", "status"], name: "index_contractor_payments_on_contractor_id_and_status"
    t.index ["contractor_id"], name: "index_contractor_payments_on_contractor_id"
    t.index ["status", "pay_date"], name: "index_contractor_payments_on_status_and_pay_date"
  end

  create_table "contractors", force: :cascade do |t|
    t.string "business_name"
    t.string "contractor_type", default: "individual", null: false
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.integer "employer_id", null: false
    t.string "first_name", null: false
    t.integer "hourly_rate_cents", default: 0, null: false
    t.string "last_name", null: false
    t.json "metadata", default: {}, null: false
    t.string "payment_method_status", default: "missing", null: false
    t.date "start_on"
    t.string "status", default: "onboarding", null: false
    t.string "tax_form_status", default: "missing", null: false
    t.datetime "updated_at", null: false
    t.index ["employer_id", "email"], name: "index_contractors_on_employer_id_and_email", unique: true
    t.index ["employer_id", "status"], name: "index_contractors_on_employer_id_and_status"
    t.index ["employer_id"], name: "index_contractors_on_employer_id"
    t.index ["payment_method_status"], name: "index_contractors_on_payment_method_status"
    t.index ["tax_form_status"], name: "index_contractors_on_tax_form_status"
  end

  create_table "departments", force: :cascade do |t|
    t.integer "budget_cents", default: 0, null: false
    t.string "code", null: false
    t.datetime "created_at", null: false
    t.integer "employer_id", null: false
    t.integer "manager_id"
    t.json "metadata", default: {}, null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["employer_id", "code"], name: "index_departments_on_employer_id_and_code", unique: true
    t.index ["employer_id"], name: "index_departments_on_employer_id"
    t.index ["manager_id"], name: "index_departments_on_manager_id"
  end

  create_table "dependents", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.date "date_of_birth"
    t.string "eligibility_status", default: "needs_review", null: false
    t.integer "employee_id", null: false
    t.string "enrollment_status", default: "pending", null: false
    t.string "first_name", null: false
    t.string "last_name", null: false
    t.json "metadata", default: {}, null: false
    t.string "relationship", null: false
    t.datetime "updated_at", null: false
    t.string "vitable_id"
    t.index ["eligibility_status", "enrollment_status"], name: "index_dependents_on_eligibility_status_and_enrollment_status"
    t.index ["employee_id", "relationship"], name: "index_dependents_on_employee_id_and_relationship"
    t.index ["employee_id", "vitable_id"], name: "index_dependents_on_employee_id_and_vitable_id", unique: true
    t.index ["employee_id"], name: "index_dependents_on_employee_id"
  end

  create_table "employee_bank_accounts", force: :cascade do |t|
    t.string "account_last4", null: false
    t.string "account_type", default: "checking", null: false
    t.string "allocation_type", default: "remainder", null: false
    t.integer "allocation_value", default: 100, null: false
    t.datetime "created_at", null: false
    t.integer "employee_id", null: false
    t.string "institution_name", null: false
    t.json "metadata", default: {}, null: false
    t.string "nickname", null: false
    t.datetime "prenote_sent_at"
    t.boolean "primary_account", default: true, null: false
    t.string "routing_number_last4", null: false
    t.string "status", default: "pending_verification", null: false
    t.datetime "updated_at", null: false
    t.string "verification_method", default: "prenote", null: false
    t.datetime "verified_at"
    t.index ["employee_id", "primary_account"], name: "idx_on_employee_id_primary_account_3aa60fffea"
    t.index ["employee_id", "status"], name: "index_employee_bank_accounts_on_employee_id_and_status"
    t.index ["employee_id"], name: "index_employee_bank_accounts_on_employee_id"
    t.index ["status"], name: "index_employee_bank_accounts_on_status"
  end

  create_table "employee_change_requests", force: :cascade do |t|
    t.datetime "applied_at"
    t.datetime "created_at", null: false
    t.date "effective_on", null: false
    t.integer "employee_id", null: false
    t.json "metadata", default: {}, null: false
    t.datetime "rejected_at"
    t.string "request_type", null: false
    t.datetime "reviewed_at"
    t.string "reviewed_by"
    t.string "status", default: "submitted", null: false
    t.datetime "submitted_at", null: false
    t.text "summary"
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["employee_id", "status"], name: "index_employee_change_requests_on_employee_id_and_status"
    t.index ["employee_id"], name: "index_employee_change_requests_on_employee_id"
    t.index ["request_type", "status"], name: "index_employee_change_requests_on_request_type_and_status"
    t.index ["status", "submitted_at"], name: "index_employee_change_requests_on_status_and_submitted_at"
  end

  create_table "employee_deductions", force: :cascade do |t|
    t.string "agency_name"
    t.integer "amount_cents", default: 0, null: false
    t.datetime "approved_at"
    t.string "calculation_method", default: "fixed_amount", null: false
    t.string "case_number"
    t.datetime "closed_at"
    t.datetime "created_at", null: false
    t.integer "current_balance_cents"
    t.string "deduction_type", default: "other", null: false
    t.integer "employee_id", null: false
    t.integer "employer_id", null: false
    t.date "ends_on"
    t.integer "max_per_paycheck_cents"
    t.json "metadata", default: {}, null: false
    t.datetime "paused_at"
    t.integer "percent_basis_points"
    t.boolean "pre_tax", default: false, null: false
    t.integer "priority", default: 50, null: false
    t.date "starts_on", null: false
    t.string "status", default: "pending", null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["case_number", "agency_name"], name: "index_employee_deductions_on_case_number_and_agency_name"
    t.index ["deduction_type", "priority"], name: "index_employee_deductions_on_deduction_type_and_priority"
    t.index ["employee_id", "status"], name: "index_employee_deductions_on_employee_id_and_status"
    t.index ["employee_id"], name: "index_employee_deductions_on_employee_id"
    t.index ["employer_id", "status"], name: "index_employee_deductions_on_employer_id_and_status"
    t.index ["employer_id"], name: "index_employee_deductions_on_employer_id"
  end

  create_table "employee_documents", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "document_type", null: false
    t.integer "employee_id", null: false
    t.date "expires_on"
    t.date "issued_on"
    t.json "metadata", default: {}, null: false
    t.datetime "requested_at"
    t.string "source", default: "employee_portal", null: false
    t.string "status", default: "pending", null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.datetime "verified_at"
    t.index ["employee_id", "document_type"], name: "index_employee_documents_on_employee_id_and_document_type"
    t.index ["employee_id"], name: "index_employee_documents_on_employee_id"
    t.index ["source"], name: "index_employee_documents_on_source"
    t.index ["status", "expires_on"], name: "index_employee_documents_on_status_and_expires_on"
    t.index ["status", "requested_at"], name: "index_employee_documents_on_status_and_requested_at"
    t.index ["status", "verified_at"], name: "index_employee_documents_on_status_and_verified_at"
  end

  create_table "employee_expenses", force: :cascade do |t|
    t.integer "amount_cents", default: 0, null: false
    t.datetime "approved_at"
    t.string "category", null: false
    t.datetime "created_at", null: false
    t.text "description"
    t.integer "employee_id", null: false
    t.date "incurred_on", null: false
    t.string "merchant", null: false
    t.json "metadata", default: {}, null: false
    t.string "payment_method", default: "employee_paid", null: false
    t.string "receipt_status", default: "missing", null: false
    t.boolean "reimbursable", default: true, null: false
    t.datetime "reimbursed_at"
    t.string "status", default: "submitted", null: false
    t.datetime "updated_at", null: false
    t.index ["category"], name: "index_employee_expenses_on_category"
    t.index ["employee_id", "incurred_on"], name: "index_employee_expenses_on_employee_id_and_incurred_on"
    t.index ["employee_id"], name: "index_employee_expenses_on_employee_id"
    t.index ["receipt_status"], name: "index_employee_expenses_on_receipt_status"
    t.index ["status", "incurred_on"], name: "index_employee_expenses_on_status_and_incurred_on"
  end

  create_table "employee_goals", force: :cascade do |t|
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.text "description"
    t.date "due_on", null: false
    t.integer "employee_id", null: false
    t.json "metadata", default: {}, null: false
    t.string "metric"
    t.string "owner", default: "employee", null: false
    t.integer "performance_cycle_id"
    t.integer "progress_percent", default: 0, null: false
    t.string "status", default: "on_track", null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["employee_id"], name: "index_employee_goals_on_employee_id"
    t.index ["performance_cycle_id"], name: "index_employee_goals_on_performance_cycle_id"
    t.index ["status", "due_on"], name: "index_employee_goals_on_status_and_due_on"
  end

  create_table "employee_lifecycle_events", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.date "effective_on", null: false
    t.integer "employee_id", null: false
    t.string "event_type", null: false
    t.json "metadata", default: {}, null: false
    t.datetime "reviewed_at"
    t.string "source", default: "ops_console", null: false
    t.string "status", default: "draft", null: false
    t.string "summary", null: false
    t.datetime "synced_at"
    t.datetime "updated_at", null: false
    t.index ["employee_id", "effective_on"], name: "idx_on_employee_id_effective_on_68cdb12e02"
    t.index ["employee_id"], name: "index_employee_lifecycle_events_on_employee_id"
    t.index ["event_type"], name: "index_employee_lifecycle_events_on_event_type"
    t.index ["status", "effective_on"], name: "index_employee_lifecycle_events_on_status_and_effective_on"
  end

  create_table "employees", force: :cascade do |t|
    t.integer "compensation_cents", default: 0, null: false
    t.datetime "created_at", null: false
    t.date "date_of_birth"
    t.integer "department_id"
    t.string "email", null: false
    t.integer "employer_id", null: false
    t.string "employment_status", default: "active", null: false
    t.string "first_name", null: false
    t.string "last_name", null: false
    t.integer "manager_id"
    t.json "metadata", default: {}, null: false
    t.string "onboarding_status", default: "complete", null: false
    t.string "pay_type", default: "salary", null: false
    t.date "start_on"
    t.string "title"
    t.datetime "updated_at", null: false
    t.string "vitable_id"
    t.integer "work_location_id"
    t.index ["department_id", "employment_status"], name: "index_employees_on_department_id_and_employment_status"
    t.index ["department_id"], name: "index_employees_on_department_id"
    t.index ["employer_id", "email"], name: "index_employees_on_employer_id_and_email", unique: true
    t.index ["employer_id", "employment_status"], name: "index_employees_on_employer_id_and_employment_status"
    t.index ["employer_id", "manager_id"], name: "index_employees_on_employer_id_and_manager_id"
    t.index ["employer_id", "vitable_id"], name: "index_employees_on_employer_id_and_vitable_id", unique: true
    t.index ["employer_id"], name: "index_employees_on_employer_id"
    t.index ["manager_id"], name: "index_employees_on_manager_id"
    t.index ["onboarding_status"], name: "index_employees_on_onboarding_status"
    t.index ["work_location_id", "employment_status"], name: "index_employees_on_work_location_id_and_employment_status"
    t.index ["work_location_id"], name: "index_employees_on_work_location_id"
  end

  create_table "employer_bank_accounts", force: :cascade do |t|
    t.string "account_last4", null: false
    t.string "account_type", default: "checking", null: false
    t.datetime "created_at", null: false
    t.integer "employer_id", null: false
    t.string "institution_name", null: false
    t.json "metadata", default: {}, null: false
    t.string "name", null: false
    t.boolean "primary_account", default: false, null: false
    t.string "routing_number_last4", null: false
    t.string "status", default: "pending_verification", null: false
    t.datetime "updated_at", null: false
    t.string "verification_method", default: "microdeposit", null: false
    t.datetime "verified_at"
    t.index ["employer_id", "primary_account"], name: "idx_on_employer_id_primary_account_1cd9642011"
    t.index ["employer_id", "status"], name: "index_employer_bank_accounts_on_employer_id_and_status"
    t.index ["employer_id"], name: "index_employer_bank_accounts_on_employer_id"
    t.index ["status"], name: "index_employer_bank_accounts_on_status"
  end

  create_table "employers", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "ein"
    t.string "legal_name"
    t.string "name", null: false
    t.datetime "onboarded_at"
    t.integer "organization_id", null: false
    t.json "settings", default: {}, null: false
    t.string "status", default: "draft", null: false
    t.datetime "updated_at", null: false
    t.string "vitable_id"
    t.index ["ein"], name: "index_employers_on_ein"
    t.index ["organization_id", "status"], name: "index_employers_on_organization_id_and_status"
    t.index ["organization_id", "vitable_id"], name: "index_employers_on_organization_id_and_vitable_id", unique: true
    t.index ["organization_id"], name: "index_employers_on_organization_id"
  end

  create_table "enrollments", force: :cascade do |t|
    t.datetime "accepted_at"
    t.integer "benefit_plan_id", null: false
    t.string "coverage_level", default: "employee", null: false
    t.datetime "created_at", null: false
    t.date "effective_on"
    t.integer "employee_id", null: false
    t.json "metadata", default: {}, null: false
    t.string "status", default: "pending", null: false
    t.datetime "updated_at", null: false
    t.string "vitable_id"
    t.index ["benefit_plan_id"], name: "index_enrollments_on_benefit_plan_id"
    t.index ["employee_id", "benefit_plan_id"], name: "index_enrollments_on_employee_id_and_benefit_plan_id", unique: true
    t.index ["employee_id", "vitable_id"], name: "index_enrollments_on_employee_id_and_vitable_id", unique: true
    t.index ["employee_id"], name: "index_enrollments_on_employee_id"
    t.index ["status"], name: "index_enrollments_on_status"
  end

  create_table "integration_connections", force: :cascade do |t|
    t.string "api_key_reference", default: "VITABLE_CONNECT_API_KEY", null: false
    t.datetime "created_at", null: false
    t.string "environment", default: "production", null: false
    t.datetime "last_synced_at"
    t.json "metadata", default: {}, null: false
    t.integer "organization_id", null: false
    t.string "provider", null: false
    t.string "status", default: "needs_credentials", null: false
    t.datetime "updated_at", null: false
    t.string "webhook_secret_reference"
    t.index ["organization_id", "provider", "environment"], name: "idx_integration_connections_unique_provider_environment", unique: true
    t.index ["organization_id"], name: "index_integration_connections_on_organization_id"
    t.index ["status"], name: "index_integration_connections_on_status"
  end

  create_table "job_openings", force: :cascade do |t|
    t.string "code", null: false
    t.integer "compensation_max_cents", default: 0, null: false
    t.integer "compensation_min_cents", default: 0, null: false
    t.datetime "created_at", null: false
    t.integer "department_id"
    t.text "description"
    t.integer "employer_id", null: false
    t.string "employment_type", default: "full_time", null: false
    t.integer "headcount", default: 1, null: false
    t.json "metadata", default: {}, null: false
    t.boolean "remote", default: false, null: false
    t.string "status", default: "open", null: false
    t.date "target_start_on"
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.integer "work_location_id"
    t.index ["department_id"], name: "index_job_openings_on_department_id"
    t.index ["employer_id", "code"], name: "index_job_openings_on_employer_id_and_code", unique: true
    t.index ["employer_id", "status"], name: "index_job_openings_on_employer_id_and_status"
    t.index ["employer_id"], name: "index_job_openings_on_employer_id"
    t.index ["status", "target_start_on"], name: "index_job_openings_on_status_and_target_start_on"
    t.index ["work_location_id"], name: "index_job_openings_on_work_location_id"
  end

  create_table "onboarding_tasks", force: :cascade do |t|
    t.string "category", null: false
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.date "due_on", null: false
    t.integer "employee_id", null: false
    t.json "metadata", default: {}, null: false
    t.string "owner", default: "people", null: false
    t.string "status", default: "open", null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["due_on", "status"], name: "index_onboarding_tasks_on_due_on_and_status"
    t.index ["employee_id", "status"], name: "index_onboarding_tasks_on_employee_id_and_status"
    t.index ["employee_id"], name: "index_onboarding_tasks_on_employee_id"
  end

  create_table "open_enrollment_campaigns", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "employer_id", null: false
    t.date "ends_on", null: false
    t.datetime "launched_at"
    t.json "metadata", default: {}, null: false
    t.string "name", null: false
    t.integer "plan_year", null: false
    t.datetime "reminders_sent_at"
    t.date "starts_on", null: false
    t.string "status", default: "draft", null: false
    t.datetime "updated_at", null: false
    t.index ["employer_id", "plan_year"], name: "index_open_enrollment_campaigns_on_employer_id_and_plan_year", unique: true
    t.index ["employer_id"], name: "index_open_enrollment_campaigns_on_employer_id"
    t.index ["status", "starts_on"], name: "index_open_enrollment_campaigns_on_status_and_starts_on"
  end

  create_table "open_enrollment_invitations", force: :cascade do |t|
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.date "due_on", null: false
    t.integer "employee_id", null: false
    t.datetime "last_reminded_at"
    t.json "metadata", default: {}, null: false
    t.integer "open_enrollment_campaign_id", null: false
    t.datetime "opened_at"
    t.datetime "sent_at"
    t.string "status", default: "not_sent", null: false
    t.datetime "updated_at", null: false
    t.index ["employee_id"], name: "index_open_enrollment_invitations_on_employee_id"
    t.index ["open_enrollment_campaign_id", "employee_id"], name: "idx_open_enrollment_invites_on_campaign_employee", unique: true
    t.index ["open_enrollment_campaign_id"], name: "idx_on_open_enrollment_campaign_id_33c3f56dd0"
    t.index ["status", "due_on"], name: "index_open_enrollment_invitations_on_status_and_due_on"
  end

  create_table "organizations", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "external_id"
    t.json "metadata", default: {}, null: false
    t.string "name", null: false
    t.string "status", default: "active", null: false
    t.datetime "updated_at", null: false
    t.index ["external_id"], name: "index_organizations_on_external_id", unique: true
    t.index ["status"], name: "index_organizations_on_status"
  end

  create_table "pay_statements", force: :cascade do |t|
    t.integer "adjustment_cents", default: 0, null: false
    t.datetime "created_at", null: false
    t.integer "deduction_cents", default: 0, null: false
    t.datetime "delivered_at"
    t.string "delivery_method", default: "employee_portal", null: false
    t.integer "employee_id", null: false
    t.integer "gross_pay_cents", default: 0, null: false
    t.json "metadata", default: {}, null: false
    t.integer "net_pay_cents", default: 0, null: false
    t.date "pay_date", null: false
    t.integer "payroll_run_id", null: false
    t.date "period_end_on", null: false
    t.date "period_start_on", null: false
    t.string "statement_number", null: false
    t.string "status", default: "generated", null: false
    t.integer "tax_cents", default: 0, null: false
    t.datetime "updated_at", null: false
    t.datetime "viewed_at"
    t.index ["employee_id", "pay_date"], name: "index_pay_statements_on_employee_id_and_pay_date"
    t.index ["employee_id"], name: "index_pay_statements_on_employee_id"
    t.index ["payroll_run_id", "employee_id"], name: "index_pay_statements_on_payroll_run_id_and_employee_id", unique: true
    t.index ["payroll_run_id", "status"], name: "index_pay_statements_on_payroll_run_id_and_status"
    t.index ["payroll_run_id"], name: "index_pay_statements_on_payroll_run_id"
    t.index ["statement_number"], name: "index_pay_statements_on_statement_number", unique: true
    t.index ["status"], name: "index_pay_statements_on_status"
  end

  create_table "payroll_adjustments", force: :cascade do |t|
    t.string "adjustment_type", null: false
    t.integer "amount_cents", default: 0, null: false
    t.datetime "created_at", null: false
    t.string "description", null: false
    t.integer "employee_id", null: false
    t.json "metadata", default: {}, null: false
    t.integer "payroll_run_id", null: false
    t.boolean "taxable", default: true, null: false
    t.datetime "updated_at", null: false
    t.index ["adjustment_type"], name: "index_payroll_adjustments_on_adjustment_type"
    t.index ["employee_id"], name: "index_payroll_adjustments_on_employee_id"
    t.index ["payroll_run_id", "employee_id"], name: "index_payroll_adjustments_on_payroll_run_id_and_employee_id"
    t.index ["payroll_run_id"], name: "index_payroll_adjustments_on_payroll_run_id"
  end

  create_table "payroll_approval_steps", force: :cascade do |t|
    t.datetime "completed_at"
    t.string "completed_by"
    t.datetime "created_at", null: false
    t.datetime "due_at", null: false
    t.string "key", null: false
    t.json "metadata", default: {}, null: false
    t.string "owner", null: false
    t.integer "payroll_run_id", null: false
    t.integer "payroll_schedule_id"
    t.integer "position", default: 0, null: false
    t.string "severity", default: "medium", null: false
    t.string "status", default: "open", null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["payroll_run_id", "key"], name: "index_payroll_approval_steps_on_payroll_run_id_and_key", unique: true
    t.index ["payroll_run_id"], name: "index_payroll_approval_steps_on_payroll_run_id"
    t.index ["payroll_schedule_id"], name: "index_payroll_approval_steps_on_payroll_schedule_id"
    t.index ["position", "due_at"], name: "index_payroll_approval_steps_on_position_and_due_at"
    t.index ["status", "due_at"], name: "index_payroll_approval_steps_on_status_and_due_at"
  end

  create_table "payroll_deductions", force: :cascade do |t|
    t.integer "amount_cents", default: 0, null: false
    t.string "code", null: false
    t.datetime "created_at", null: false
    t.integer "employee_id", null: false
    t.integer "enrollment_id"
    t.json "metadata", default: {}, null: false
    t.integer "payroll_run_id", null: false
    t.string "status", default: "estimated", null: false
    t.datetime "updated_at", null: false
    t.string "vitable_id"
    t.index ["employee_id"], name: "index_payroll_deductions_on_employee_id"
    t.index ["enrollment_id"], name: "index_payroll_deductions_on_enrollment_id"
    t.index ["payroll_run_id", "employee_id", "code"], name: "idx_payroll_deductions_on_run_employee_code"
    t.index ["payroll_run_id"], name: "index_payroll_deductions_on_payroll_run_id"
    t.index ["status"], name: "index_payroll_deductions_on_status"
    t.index ["vitable_id"], name: "index_payroll_deductions_on_vitable_id", unique: true
  end

  create_table "payroll_runs", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "employer_id", null: false
    t.integer "gross_pay_cents", default: 0, null: false
    t.json "metadata", default: {}, null: false
    t.date "pay_date", null: false
    t.date "period_end_on", null: false
    t.date "period_start_on", null: false
    t.string "status", default: "draft", null: false
    t.datetime "updated_at", null: false
    t.index ["employer_id", "pay_date"], name: "index_payroll_runs_on_employer_id_and_pay_date"
    t.index ["employer_id", "status"], name: "index_payroll_runs_on_employer_id_and_status"
    t.index ["employer_id"], name: "index_payroll_runs_on_employer_id"
  end

  create_table "payroll_schedules", force: :cascade do |t|
    t.datetime "approval_deadline_at", null: false
    t.string "cadence", null: false
    t.datetime "created_at", null: false
    t.integer "employer_id", null: false
    t.datetime "funding_deadline_at", null: false
    t.json "metadata", default: {}, null: false
    t.string "name", null: false
    t.date "next_pay_date", null: false
    t.date "next_period_end_on", null: false
    t.date "next_period_start_on", null: false
    t.date "period_anchor_on", null: false
    t.string "status", default: "active", null: false
    t.string "timezone", default: "America/Los_Angeles", null: false
    t.datetime "updated_at", null: false
    t.index ["employer_id", "name"], name: "index_payroll_schedules_on_employer_id_and_name", unique: true
    t.index ["employer_id", "status", "next_pay_date"], name: "idx_on_employer_id_status_next_pay_date_a9008d209f"
    t.index ["employer_id"], name: "index_payroll_schedules_on_employer_id"
  end

  create_table "performance_cycles", force: :cascade do |t|
    t.datetime "closed_at"
    t.datetime "created_at", null: false
    t.date "due_on", null: false
    t.integer "employer_id", null: false
    t.datetime "launched_at"
    t.json "metadata", default: {}, null: false
    t.string "name", null: false
    t.date "period_end_on", null: false
    t.date "period_start_on", null: false
    t.string "review_type", default: "quarterly", null: false
    t.string "status", default: "draft", null: false
    t.datetime "updated_at", null: false
    t.index ["employer_id", "period_start_on", "period_end_on"], name: "index_performance_cycles_on_employer_and_period"
    t.index ["employer_id", "status"], name: "index_performance_cycles_on_employer_id_and_status"
    t.index ["employer_id"], name: "index_performance_cycles_on_employer_id"
  end

  create_table "performance_reviews", force: :cascade do |t|
    t.datetime "calibrated_at"
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.date "due_on", null: false
    t.integer "employee_id", null: false
    t.text "growth_areas"
    t.datetime "manager_submitted_at"
    t.json "metadata", default: {}, null: false
    t.integer "performance_cycle_id", null: false
    t.integer "rating"
    t.integer "reviewer_id"
    t.datetime "self_submitted_at"
    t.string "status", default: "draft", null: false
    t.text "strengths"
    t.datetime "updated_at", null: false
    t.index ["employee_id"], name: "index_performance_reviews_on_employee_id"
    t.index ["performance_cycle_id", "employee_id"], name: "index_performance_reviews_on_cycle_and_employee", unique: true
    t.index ["performance_cycle_id"], name: "index_performance_reviews_on_performance_cycle_id"
    t.index ["reviewer_id"], name: "index_performance_reviews_on_reviewer_id"
    t.index ["status", "due_on"], name: "index_performance_reviews_on_status_and_due_on"
  end

  create_table "shift_swap_requests", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.json "metadata", default: {}, null: false
    t.text "reason"
    t.integer "requester_id", null: false
    t.datetime "reviewed_at"
    t.string "reviewed_by"
    t.string "status", default: "submitted", null: false
    t.datetime "submitted_at"
    t.integer "target_employee_id"
    t.datetime "updated_at", null: false
    t.integer "work_shift_id", null: false
    t.index ["requester_id", "status"], name: "index_shift_swap_requests_on_requester_id_and_status"
    t.index ["requester_id"], name: "index_shift_swap_requests_on_requester_id"
    t.index ["status", "submitted_at"], name: "index_shift_swap_requests_on_status_and_submitted_at"
    t.index ["target_employee_id"], name: "index_shift_swap_requests_on_target_employee_id"
    t.index ["work_shift_id"], name: "index_shift_swap_requests_on_work_shift_id"
  end

  create_table "sync_runs", force: :cascade do |t|
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.text "error_message"
    t.integer "integration_connection_id", null: false
    t.string "operation", null: false
    t.string "resource_type", null: false
    t.datetime "started_at", null: false
    t.json "stats", default: {}, null: false
    t.string "status", default: "running", null: false
    t.datetime "updated_at", null: false
    t.index ["integration_connection_id", "resource_type", "created_at"], name: "idx_sync_runs_on_connection_resource_created"
    t.index ["integration_connection_id"], name: "index_sync_runs_on_integration_connection_id"
    t.index ["status"], name: "index_sync_runs_on_status"
  end

  create_table "time_entries", force: :cascade do |t|
    t.datetime "approved_at"
    t.integer "break_minutes", default: 0, null: false
    t.datetime "clock_in_at", null: false
    t.datetime "clock_out_at", null: false
    t.datetime "created_at", null: false
    t.integer "employee_id", null: false
    t.json "metadata", default: {}, null: false
    t.text "notes"
    t.datetime "reviewed_at"
    t.string "source", default: "web", null: false
    t.string "status", default: "submitted", null: false
    t.datetime "updated_at", null: false
    t.date "work_date", null: false
    t.index ["employee_id", "work_date"], name: "index_time_entries_on_employee_id_and_work_date"
    t.index ["employee_id"], name: "index_time_entries_on_employee_id"
    t.index ["source"], name: "index_time_entries_on_source"
    t.index ["status", "work_date"], name: "index_time_entries_on_status_and_work_date"
  end

  create_table "time_off_policies", force: :cascade do |t|
    t.string "accrual_method", default: "annual_grant", null: false
    t.decimal "annual_hours", precision: 8, scale: 2, default: "0.0", null: false
    t.decimal "carryover_hours", precision: 8, scale: 2, default: "0.0", null: false
    t.datetime "created_at", null: false
    t.integer "employer_id", null: false
    t.json "metadata", default: {}, null: false
    t.string "name", null: false
    t.boolean "paid", default: true, null: false
    t.string "status", default: "active", null: false
    t.datetime "updated_at", null: false
    t.index ["employer_id", "name"], name: "index_time_off_policies_on_employer_id_and_name", unique: true
    t.index ["employer_id", "status"], name: "index_time_off_policies_on_employer_id_and_status"
    t.index ["employer_id"], name: "index_time_off_policies_on_employer_id"
  end

  create_table "time_off_requests", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "employee_id", null: false
    t.date "ends_on", null: false
    t.decimal "hours", precision: 8, scale: 2, default: "0.0", null: false
    t.json "metadata", default: {}, null: false
    t.text "reason"
    t.datetime "reviewed_at"
    t.date "starts_on", null: false
    t.string "status", default: "requested", null: false
    t.integer "time_off_policy_id", null: false
    t.datetime "updated_at", null: false
    t.index ["employee_id", "starts_on"], name: "index_time_off_requests_on_employee_id_and_starts_on"
    t.index ["employee_id"], name: "index_time_off_requests_on_employee_id"
    t.index ["status", "starts_on"], name: "index_time_off_requests_on_status_and_starts_on"
    t.index ["time_off_policy_id"], name: "index_time_off_requests_on_time_off_policy_id"
  end

  create_table "training_assignments", force: :cascade do |t|
    t.string "certificate_id"
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.date "due_on", null: false
    t.integer "employee_id", null: false
    t.json "metadata", default: {}, null: false
    t.integer "score"
    t.datetime "started_at"
    t.string "status", default: "assigned", null: false
    t.integer "training_program_id", null: false
    t.datetime "updated_at", null: false
    t.index ["certificate_id"], name: "index_training_assignments_on_certificate_id"
    t.index ["employee_id"], name: "index_training_assignments_on_employee_id"
    t.index ["status", "due_on"], name: "index_training_assignments_on_status_and_due_on"
    t.index ["training_program_id", "employee_id"], name: "index_training_assignments_on_program_and_employee", unique: true
    t.index ["training_program_id"], name: "index_training_assignments_on_training_program_id"
  end

  create_table "training_programs", force: :cascade do |t|
    t.string "audience", default: "all_employees", null: false
    t.string "cadence", default: "annual", null: false
    t.string "category", default: "compliance", null: false
    t.datetime "closed_at"
    t.integer "completed_count", default: 0, null: false
    t.datetime "created_at", null: false
    t.text "description"
    t.date "due_on", null: false
    t.integer "employer_id", null: false
    t.date "launch_on"
    t.datetime "launched_at"
    t.json "metadata", default: {}, null: false
    t.integer "overdue_count", default: 0, null: false
    t.integer "required_count", default: 0, null: false
    t.string "status", default: "draft", null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["category", "due_on"], name: "index_training_programs_on_category_and_due_on"
    t.index ["employer_id", "status"], name: "index_training_programs_on_employer_id_and_status"
    t.index ["employer_id"], name: "index_training_programs_on_employer_id"
  end

  create_table "webhook_events", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "error_message"
    t.string "event_id", null: false
    t.string "event_name", null: false
    t.integer "integration_connection_id"
    t.datetime "occurred_at", null: false
    t.string "organization_external_id", null: false
    t.json "payload", default: {}, null: false
    t.datetime "processed_at"
    t.string "resource_id", null: false
    t.string "resource_type", null: false
    t.string "status", default: "received", null: false
    t.datetime "updated_at", null: false
    t.index ["event_id"], name: "index_webhook_events_on_event_id", unique: true
    t.index ["integration_connection_id"], name: "index_webhook_events_on_integration_connection_id"
    t.index ["organization_external_id", "created_at"], name: "idx_on_organization_external_id_created_at_b07d56a3a4"
    t.index ["resource_type", "resource_id"], name: "index_webhook_events_on_resource_type_and_resource_id"
    t.index ["status"], name: "index_webhook_events_on_status"
  end

  create_table "work_locations", force: :cascade do |t|
    t.string "address_line1"
    t.string "city"
    t.string "country", default: "US", null: false
    t.datetime "created_at", null: false
    t.integer "employer_id", null: false
    t.json "metadata", default: {}, null: false
    t.string "name", null: false
    t.string "postal_code"
    t.boolean "remote", default: false, null: false
    t.string "state"
    t.datetime "updated_at", null: false
    t.index ["employer_id", "name"], name: "index_work_locations_on_employer_id_and_name", unique: true
    t.index ["employer_id", "state"], name: "index_work_locations_on_employer_id_and_state"
    t.index ["employer_id"], name: "index_work_locations_on_employer_id"
  end

  create_table "work_shifts", force: :cascade do |t|
    t.integer "break_minutes", default: 0, null: false
    t.datetime "created_at", null: false
    t.integer "department_id"
    t.integer "employee_id"
    t.integer "employer_id", null: false
    t.datetime "ends_at", null: false
    t.integer "hourly_rate_cents", default: 0, null: false
    t.json "metadata", default: {}, null: false
    t.text "notes"
    t.datetime "published_at"
    t.string "role", null: false
    t.datetime "starts_at", null: false
    t.string "status", default: "draft", null: false
    t.datetime "updated_at", null: false
    t.integer "work_location_id"
    t.index ["department_id"], name: "index_work_shifts_on_department_id"
    t.index ["employee_id", "starts_at"], name: "index_work_shifts_on_employee_id_and_starts_at"
    t.index ["employee_id"], name: "index_work_shifts_on_employee_id"
    t.index ["employer_id", "status"], name: "index_work_shifts_on_employer_id_and_status"
    t.index ["employer_id"], name: "index_work_shifts_on_employer_id"
    t.index ["starts_at", "ends_at"], name: "index_work_shifts_on_starts_at_and_ends_at"
    t.index ["work_location_id"], name: "index_work_shifts_on_work_location_id"
  end

  add_foreign_key "api_request_logs", "integration_connections"
  add_foreign_key "benefit_invoice_lines", "benefit_invoices"
  add_foreign_key "benefit_invoice_lines", "benefit_plans"
  add_foreign_key "benefit_invoice_lines", "employees"
  add_foreign_key "benefit_invoice_lines", "enrollments"
  add_foreign_key "benefit_invoices", "employers"
  add_foreign_key "benefit_plans", "employers"
  add_foreign_key "candidates", "employees"
  add_foreign_key "candidates", "job_openings"
  add_foreign_key "compensation_changes", "employees"
  add_foreign_key "compensation_changes", "employers"
  add_foreign_key "compensation_changes", "payroll_runs"
  add_foreign_key "compliance_cases", "employees"
  add_foreign_key "compliance_cases", "employers"
  add_foreign_key "contractor_payments", "contractors"
  add_foreign_key "contractors", "employers"
  add_foreign_key "departments", "employees", column: "manager_id"
  add_foreign_key "departments", "employers"
  add_foreign_key "dependents", "employees"
  add_foreign_key "employee_bank_accounts", "employees"
  add_foreign_key "employee_change_requests", "employees"
  add_foreign_key "employee_deductions", "employees"
  add_foreign_key "employee_deductions", "employers"
  add_foreign_key "employee_documents", "employees"
  add_foreign_key "employee_expenses", "employees"
  add_foreign_key "employee_goals", "employees"
  add_foreign_key "employee_goals", "performance_cycles"
  add_foreign_key "employee_lifecycle_events", "employees"
  add_foreign_key "employees", "departments"
  add_foreign_key "employees", "employees", column: "manager_id"
  add_foreign_key "employees", "employers"
  add_foreign_key "employees", "work_locations"
  add_foreign_key "employer_bank_accounts", "employers"
  add_foreign_key "employers", "organizations"
  add_foreign_key "enrollments", "benefit_plans"
  add_foreign_key "enrollments", "employees"
  add_foreign_key "integration_connections", "organizations"
  add_foreign_key "job_openings", "departments"
  add_foreign_key "job_openings", "employers"
  add_foreign_key "job_openings", "work_locations"
  add_foreign_key "onboarding_tasks", "employees"
  add_foreign_key "open_enrollment_campaigns", "employers"
  add_foreign_key "open_enrollment_invitations", "employees"
  add_foreign_key "open_enrollment_invitations", "open_enrollment_campaigns"
  add_foreign_key "pay_statements", "employees"
  add_foreign_key "pay_statements", "payroll_runs"
  add_foreign_key "payroll_adjustments", "employees"
  add_foreign_key "payroll_adjustments", "payroll_runs"
  add_foreign_key "payroll_approval_steps", "payroll_runs"
  add_foreign_key "payroll_approval_steps", "payroll_schedules"
  add_foreign_key "payroll_deductions", "employees"
  add_foreign_key "payroll_deductions", "enrollments"
  add_foreign_key "payroll_deductions", "payroll_runs"
  add_foreign_key "payroll_runs", "employers"
  add_foreign_key "payroll_schedules", "employers"
  add_foreign_key "performance_cycles", "employers"
  add_foreign_key "performance_reviews", "employees"
  add_foreign_key "performance_reviews", "employees", column: "reviewer_id"
  add_foreign_key "performance_reviews", "performance_cycles"
  add_foreign_key "shift_swap_requests", "employees", column: "requester_id"
  add_foreign_key "shift_swap_requests", "employees", column: "target_employee_id"
  add_foreign_key "shift_swap_requests", "work_shifts"
  add_foreign_key "sync_runs", "integration_connections"
  add_foreign_key "time_entries", "employees"
  add_foreign_key "time_off_policies", "employers"
  add_foreign_key "time_off_requests", "employees"
  add_foreign_key "time_off_requests", "time_off_policies"
  add_foreign_key "training_assignments", "employees"
  add_foreign_key "training_assignments", "training_programs"
  add_foreign_key "training_programs", "employers"
  add_foreign_key "webhook_events", "integration_connections"
  add_foreign_key "work_locations", "employers"
  add_foreign_key "work_shifts", "departments"
  add_foreign_key "work_shifts", "employees"
  add_foreign_key "work_shifts", "employers"
  add_foreign_key "work_shifts", "work_locations"
end
