require "test_helper"

class OperationsWorkflowsTest < ActionDispatch::IntegrationTest
  setup do
    @organization = Organization.create!(name: "Ops Platform", external_id: "org_ops")
    @employer = @organization.employers.create!(
      name: "Ops Employer",
      legal_name: "Ops Employer LLC",
      ein: "12-3456789",
      status: "active",
      settings: {
        pay_frequency: "biweekly",
        payroll_provider: "musto_payroll",
        contribution_strategy: "fixed_employer_contribution",
        enrollment_widget: "embedded"
      }
    )
    @department = @employer.departments.create!(name: "People", code: "PPL", budget_cents: 250_000_00)
    @location = @employer.work_locations.create!(name: "Remote US", country: "US", remote: true)
    @tax_registration = @employer.tax_agency_registrations.create!(
      work_location: @location,
      agency_name: "Remote worker nexus review",
      jurisdiction: "Multi-state",
      registration_type: "remote_worker_nexus",
      deposit_schedule: "manual_review",
      status: "needs_review",
      risk_level: "high",
      due_on: Date.current + 5.days,
      owner: "Payroll",
      notes: "Remote work-state attestation is needed before agency setup can be completed."
    )
    @submitted_tax_registration = @employer.tax_agency_registrations.create!(
      agency_name: "Internal Revenue Service",
      jurisdiction: "Federal",
      registration_type: "federal_withholding",
      account_number: "12-3456789",
      deposit_schedule: "semiweekly",
      status: "submitted",
      risk_level: "low",
      due_on: Date.current + 30.days,
      submitted_at: 1.day.ago,
      confirmation_number: "IRS-EFTPS-OPS",
      next_deposit_due_on: Date.current.next_month.change(day: 15),
      owner: "Finance",
      notes: "EFTPS profile submitted for federal payroll deposits."
    )
    @employee = @employer.employees.create!(
      first_name: "Casey",
      last_name: "Ng",
      email: "casey@example.com",
      department: @department,
      work_location: @location,
      title: "People Ops Lead",
      date_of_birth: Date.new(1990, 1, 15),
      start_on: Date.current - 2.years,
      compensation_cents: 115_000_00,
      onboarding_status: "in_progress",
      metadata: { phone: "5551234567", workers_comp_class_code: "8810", workers_comp_rate_basis_points: 32, workers_comp_state: "CO" }
    )
    @employer_bank_account = @employer.employer_bank_accounts.create!(name: "Payroll checking", institution_name: "Mercury Bank", routing_number_last4: "1101", account_last4: "4821", status: "verified", primary_account: true, verified_at: 1.day.ago)
    @employee_bank_account = @employee.employee_bank_accounts.create!(nickname: "Primary checking", institution_name: "Ally", routing_number_last4: "1040", account_last4: "9088", status: "pending_verification")
    @plan = @employer.benefit_plans.create!(name: "Primary Care", category: "direct_primary_care", monthly_premium_cents: 9_900)
    @enrollment = @employee.enrollments.create!(benefit_plan: @plan, status: "accepted", effective_on: Date.current)
    @pending_plan = @employer.benefit_plans.create!(name: "Dental", category: "dental", monthly_premium_cents: 4_500)
    @pending_enrollment = @employee.enrollments.create!(benefit_plan: @pending_plan, status: "pending", effective_on: Date.current.next_month.beginning_of_month)
    @waivable_plan = @employer.benefit_plans.create!(name: "Vision", category: "vision", monthly_premium_cents: 2_500)
    @waivable_enrollment = @employee.enrollments.create!(benefit_plan: @waivable_plan, status: "pending", effective_on: Date.current.next_month.beginning_of_month)
    @dependent = @employee.dependents.create!(first_name: "Harper", last_name: "Ng", relationship: "spouse", date_of_birth: Date.current - 30.years, enrollment_status: "enrolled", eligibility_status: "eligible")
    @dependent_holdback = @employee.dependents.create!(first_name: "Rowan", last_name: "Ng", relationship: "child", date_of_birth: Date.current - 8.years, enrollment_status: "pending", eligibility_status: "needs_review")
    @open_enrollment_campaign = @employer.open_enrollment_campaigns.create!(name: "#{Date.current.year + 1} Open Enrollment", plan_year: Date.current.year + 1, starts_on: Date.current.next_month.beginning_of_month, ends_on: Date.current.next_month.beginning_of_month + 21.days, status: "active", launched_at: 1.day.ago)
    @open_enrollment_invitation = @open_enrollment_campaign.open_enrollment_invitations.create!(employee: @employee, status: "not_sent", due_on: @open_enrollment_campaign.ends_on)
    @task = @employee.onboarding_tasks.create!(title: "Confirm payroll setup", category: "payroll", due_on: Date.current)
    @pending_document = @employee.employee_documents.create!(title: "Benefits disclosure", document_type: "benefits", status: "pending", expires_on: Date.current + 30.days, requested_at: 2.days.ago)
    @complete_document = @employee.employee_documents.create!(title: "W-4", document_type: "tax", status: "complete", issued_on: Date.current, verified_at: 1.day.ago)
    @expiring_document = @employee.employee_documents.create!(title: "Handbook acknowledgment", document_type: "policy", status: "complete", issued_on: Date.current - 1.year, expires_on: Date.current + 10.days, verified_at: 1.year.ago)
    @dependent_verification = @dependent.dependent_verifications.create!(employee_document: @pending_document, verification_type: "relationship_proof", status: "needs_review", requested_on: Date.current - 5.days, due_on: Date.current + 9.days)
    @profile_change_request = @employee.employee_change_requests.create!(
      request_type: "profile_update",
      title: "Update preferred name",
      summary: "Casey submitted a preferred name change from employee self-service.",
      status: "submitted",
      effective_on: Date.current,
      submitted_at: 2.days.ago,
      metadata: {
        payload: { preferred_name: "Case" },
        impact: { payroll: "none", benefits: "none", compliance: "profile_record" }
      }
    )
    @direct_deposit_change_request = @employee.employee_change_requests.create!(
      request_type: "direct_deposit",
      title: "Replace primary direct deposit",
      summary: "Casey submitted a new primary direct deposit account.",
      status: "submitted",
      effective_on: Date.current + 1.day,
      submitted_at: 1.day.ago,
      metadata: {
        payload: {
          nickname: "New primary checking",
          institution_name: "SoFi Bank",
          account_type: "checking",
          routing_number_last4: "1188",
          account_last4: "6204",
          allocation_type: "remainder",
          allocation_value: 100
        },
        impact: { payroll: "direct_deposit_prenote", benefits: "none", compliance: "none" }
      }
    )
    @applied_employee_change_request = @employee.employee_change_requests.create!(
      request_type: "tax_withholding",
      title: "Update federal withholding",
      summary: "Casey updated W-4 withholding selections.",
      status: "applied",
      effective_on: Date.current,
      submitted_at: 3.days.ago,
      reviewed_at: 2.days.ago,
      reviewed_by: "people_ops",
      applied_at: 2.days.ago,
      metadata: {
        payload: { filing_status: "head_of_household", extra_withholding_cents: 5_000 },
        impact: { payroll: "tax_withholding_update", benefits: "none", compliance: "w4_document" }
      }
    )
    @performance_cycle = @employer.performance_cycles.create!(name: "Midyear Performance Review", status: "active", review_type: "quarterly", period_start_on: Date.current.beginning_of_year, period_end_on: Date.current.beginning_of_year + 6.months - 1.day, due_on: Date.current + 14.days, launched_at: 1.day.ago)
    @draft_performance_cycle = @employer.performance_cycles.create!(name: "Year-End Performance Review", status: "draft", review_type: "annual", period_start_on: Date.current.beginning_of_year, period_end_on: Date.current.end_of_year, due_on: Date.current.end_of_year + 14.days)
    @manager_review = @performance_cycle.performance_reviews.create!(employee: @employee, reviewer: @employee, status: "manager_review", rating: 4, due_on: Date.current + 7.days, strengths: "Strong operating cadence", growth_areas: "Delegate recurring reporting")
    @holdback_review = @draft_performance_cycle.performance_reviews.create!(employee: @employee, reviewer: @employee, status: "self_review", due_on: Date.current + 21.days)
    @at_risk_goal = @employee.employee_goals.create!(performance_cycle: @performance_cycle, title: "Build payroll audit coverage", description: "Create backup coverage for payroll exception review.", status: "at_risk", progress_percent: 35, due_on: Date.current + 10.days, owner: "manager", metric: "Audit backup assigned")
    @training_program = @employer.training_programs.create!(title: "Annual compliance essentials", category: "compliance", status: "active", due_on: Date.current + 14.days, launched_at: 2.days.ago, description: "Required annual compliance program.")
    @draft_training_program = @employer.training_programs.create!(title: "Benefits policy attestation", category: "benefits", status: "draft", due_on: Date.current + 28.days, description: "Benefits eligibility and deduction attestation.")
    @completed_training_assignment = @training_program.training_assignments.create!(employee: @employee, status: "complete", due_on: Date.current + 14.days, completed_at: 1.day.ago, score: 98, certificate_id: "TRN-#{@training_program.id}-#{@employee.id}")
    @open_training_assignment = @draft_training_program.training_assignments.create!(employee: @employee, status: "assigned", due_on: Date.current + 28.days)
    @training_program.refresh_counts!
    @draft_training_program.refresh_counts!
    @job_opening = @employer.job_openings.create!(title: "Payroll Implementation Lead", code: "PAY-LEAD", department: @department, work_location: @location, compensation_min_cents: 98_000_00, compensation_max_cents: 128_000_00, target_start_on: Date.current + 21.days)
    @offerable_candidate = @job_opening.candidates.create!(first_name: "Nia", last_name: "Okafor", email: "nia.candidate@example.com", source: "referral", stage: "screening", score: 91, applied_on: Date.current - 5.days, target_start_on: Date.current + 21.days, compensation_cents: 118_000_00)
    @accepted_candidate = @job_opening.candidates.create!(first_name: "Miles", last_name: "Sato", email: "miles.candidate@example.com", source: "direct", stage: "accepted", score: 95, applied_on: Date.current - 12.days, target_start_on: Date.current + 28.days, compensation_cents: 122_000_00, offer_sent_at: 2.days.ago, accepted_at: 1.day.ago)
    @policy = @employer.time_off_policies.create!(name: "PTO", annual_hours: 120)
    @time_off_request = @employee.time_off_requests.create!(time_off_policy: @policy, starts_on: Date.current + 1.day, ends_on: Date.current + 2.days, hours: 16)
    @sick_policy = @employer.time_off_policies.create!(name: "Sick Leave", accrual_method: "state_accrual", annual_hours: 56, carryover_hours: 16)
    @approved_time_off_request = @employee.time_off_requests.create!(time_off_policy: @sick_policy, starts_on: Date.current + 10.days, ends_on: Date.current + 10.days, hours: 8, status: "approved", reviewed_at: 1.day.ago)
    @time_off_accrual = @employee.time_off_accruals.create!(time_off_policy: @policy, accrual_type: "monthly_accrual", hours: 10, period_start_on: Date.current.beginning_of_month, period_end_on: Date.current.end_of_month, effective_on: Date.current.end_of_month, status: "pending", source: "system")
    @approved_time_off_accrual = @employee.time_off_accruals.create!(time_off_policy: @sick_policy, accrual_type: "carryover", hours: 16, period_start_on: Date.current.beginning_of_month, period_end_on: Date.current.end_of_month, effective_on: Date.current.end_of_month, status: "approved", source: "import", approved_at: 1.day.ago)
    @published_shift = @employer.work_shifts.create!(employee: @employee, department: @department, work_location: @location, role: "People ops coverage", status: "published", starts_at: (Date.current + 2.days).in_time_zone.change(hour: 9), ends_at: (Date.current + 2.days).in_time_zone.change(hour: 17), break_minutes: 30, hourly_rate_cents: 4_500, published_at: 1.day.ago)
    @draft_shift = @employer.work_shifts.create!(employee: @employee, department: @department, work_location: @location, role: "Payroll close support", status: "draft", starts_at: (Date.current + 3.days).in_time_zone.change(hour: 10), ends_at: (Date.current + 3.days).in_time_zone.change(hour: 18), break_minutes: 30, hourly_rate_cents: 4_500)
    @open_shift = @employer.work_shifts.create!(department: @department, work_location: @location, role: "Open benefits desk", status: "draft", starts_at: (Date.current + 4.days).in_time_zone.change(hour: 8), ends_at: (Date.current + 4.days).in_time_zone.change(hour: 16), break_minutes: 30, hourly_rate_cents: 3_800)
    @missed_shift = @employer.work_shifts.create!(employee: @employee, department: @department, work_location: @location, role: "Missed payroll prep", status: "missed", starts_at: (Date.current - 1.day).in_time_zone.change(hour: 9), ends_at: (Date.current - 1.day).in_time_zone.change(hour: 17), break_minutes: 30, hourly_rate_cents: 4_500)
    @shift_swap_request = @published_shift.shift_swap_requests.create!(requester: @employee, target_employee: @employee, status: "submitted", reason: "Coverage requested for benefits review", submitted_at: 3.hours.ago)
    @payroll_run = @employer.payroll_runs.create!(period_start_on: Date.current.beginning_of_month, period_end_on: Date.current.end_of_month, pay_date: Date.current.end_of_month, gross_pay_cents: 9_500_00, status: "estimated")
    @payroll_run.payroll_deductions.create!(employee: @employee, enrollment: @enrollment, code: "VITABLE_BENEFITS", amount_cents: 9_900, status: "ready")
    @pending_deduction = @payroll_run.payroll_deductions.create!(employee: @employee, enrollment: @pending_enrollment, code: "VITABLE_DENTAL", amount_cents: 0, status: "waiting_on_enrollment")
    @waivable_deduction = @payroll_run.payroll_deductions.create!(employee: @employee, enrollment: @waivable_enrollment, code: "VITABLE_VISION", amount_cents: 0, status: "waiting_on_enrollment")
    @active_employee_deduction = @employer.employee_deductions.create!(employee: @employee, title: "Child support order", deduction_type: "child_support", status: "active", calculation_method: "fixed_amount", amount_cents: 225_00, priority: 10, agency_name: "County Domestic Relations", case_number: "DR-1001", starts_on: Date.current - 1.month, approved_at: 1.week.ago, metadata: { service_state: "CO", remittance_method: "state_disbursement_unit" })
    @blocked_garnishment_order = @employer.employee_deductions.create!(employee: @employee, title: "Tax levy order", deduction_type: "tax_levy", status: "blocked", calculation_method: "court_order", amount_cents: 150_00, current_balance_cents: 900_00, priority: 5, agency_name: "State Revenue Department", case_number: "LEVY-1001", starts_on: Date.current - 2.weeks, metadata: { service_state: "CO", remittance_method: "agency_ach" })
    @pending_employee_deduction = @employer.employee_deductions.create!(employee: @employee, title: "Equipment repayment", deduction_type: "equipment", status: "pending", calculation_method: "remaining_balance", amount_cents: 75_00, current_balance_cents: 300_00, priority: 60, agency_name: "Ops Employer", case_number: "EQ-22", starts_on: Date.current + 5.days)
    @pausable_employee_deduction = @employer.employee_deductions.create!(employee: @employee, title: "Retirement deferral", deduction_type: "retirement", status: "active", calculation_method: "percent_gross", amount_cents: 0, percent_basis_points: 500, max_per_paycheck_cents: 350_00, priority: 30, pre_tax: true, agency_name: "Musto Retirement", case_number: "RET-01", starts_on: Date.current - 2.months, approved_at: 2.weeks.ago)
    @payroll_adjustment = @payroll_run.payroll_adjustments.create!(employee: @employee, adjustment_type: "bonus", description: "Quarterly performance bonus", amount_cents: 1_500_00, taxable: true)
    @pay_statement = @payroll_run.pay_statements.create!(employee: @employee, statement_number: "PS-#{@payroll_run.id}-#{@employee.id}", period_start_on: @payroll_run.period_start_on, period_end_on: @payroll_run.period_end_on, pay_date: @payroll_run.pay_date, gross_pay_cents: 4_791_66, adjustment_cents: @payroll_adjustment.amount_cents, deduction_cents: 9_900, tax_cents: 86_250, net_pay_cents: 5_345_16)
    @payroll_schedule = @employer.payroll_schedules.create!(name: "Primary payroll schedule", cadence: "biweekly", period_anchor_on: @payroll_run.period_start_on, next_period_start_on: @payroll_run.period_start_on, next_period_end_on: @payroll_run.period_end_on, next_pay_date: @payroll_run.pay_date, approval_deadline_at: @payroll_run.pay_date.in_time_zone.change(hour: 12) - 2.days, funding_deadline_at: @payroll_run.pay_date.in_time_zone.change(hour: 14) - 1.day)
    @payroll_approval_step = @payroll_run.payroll_approval_steps.create!(payroll_schedule: @payroll_schedule, key: "adjustment_review", title: "Certify payroll adjustments", owner: "Payroll", status: "open", due_at: @payroll_schedule.approval_deadline_at - 4.hours, position: 2, metadata: { detail: "One adjustment needs payroll approval.", count: 1, amount_cents: @payroll_adjustment.amount_cents })
    @submitted_compensation_change = @employer.compensation_changes.create!(employee: @employee, payroll_run: @payroll_run, change_type: "merit_increase", status: "submitted", reason: "Annual merit adjustment for benefits implementation ownership.", current_compensation_cents: @employee.compensation_cents, proposed_compensation_cents: @employee.compensation_cents + 5_000_00, delta_cents: 5_000_00, effective_on: Date.current + 15.days, submitted_by: "people_ops", submitted_at: 1.day.ago)
    @approved_compensation_change = @employer.compensation_changes.create!(employee: @employee, payroll_run: @payroll_run, change_type: "promotion", status: "approved", reason: "Promotion into senior people operations role.", current_compensation_cents: @employee.compensation_cents, proposed_compensation_cents: @employee.compensation_cents + 10_000_00, delta_cents: 10_000_00, effective_on: Date.current + 10.days, submitted_by: "people_ops", submitted_at: 4.days.ago, approved_by: "finance_admin", approved_at: 1.day.ago)
    @bonus_compensation_change = @employer.compensation_changes.create!(employee: @employee, payroll_run: @payroll_run, change_type: "one_time_bonus", status: "approved", reason: "Open enrollment implementation bonus.", current_compensation_cents: @employee.compensation_cents, proposed_compensation_cents: @employee.compensation_cents, delta_cents: 750_00, effective_on: @payroll_run.pay_date, submitted_by: "people_ops", submitted_at: 3.days.ago, approved_by: "finance_admin", approved_at: 12.hours.ago)
    @rejectable_compensation_change = @employer.compensation_changes.create!(employee: @employee, payroll_run: @payroll_run, change_type: "market_adjustment", status: "submitted", reason: "Market adjustment pending leveling review.", current_compensation_cents: @employee.compensation_cents, proposed_compensation_cents: @employee.compensation_cents + 3_000_00, delta_cents: 3_000_00, effective_on: Date.current + 20.days, submitted_by: "people_ops", submitted_at: 2.days.ago)
    @benefit_invoice = @employer.benefit_invoices.create!(invoice_number: "VIT-#{@employer.id}-#{Date.current.strftime("%Y%m")}", carrier: "Vitable", period_start_on: Date.current.beginning_of_month, period_end_on: Date.current.end_of_month, due_on: Date.current.end_of_month + 10.days, status: "needs_review", total_premium_cents: 15_400, employee_contribution_cents: 9_900, employer_contribution_cents: 5_500, variance_cents: 1_000)
    @benefit_invoice_line = @benefit_invoice.benefit_invoice_lines.create!(employee: @employee, benefit_plan: @plan, enrollment: @enrollment, coverage_level: "employee", amount_cents: 9_900, expected_premium_cents: 9_900, expected_payroll_deduction_cents: 9_900, employee_contribution_cents: 9_900, employer_contribution_cents: 0, variance_cents: 0, status: "matched")
    @benefit_invoice_variance_line = @benefit_invoice.benefit_invoice_lines.create!(employee: @employee, benefit_plan: @pending_plan, enrollment: @pending_enrollment, coverage_level: "employee", amount_cents: 5_500, expected_premium_cents: 4_500, expected_payroll_deduction_cents: 0, employee_contribution_cents: 0, employer_contribution_cents: 5_500, variance_cents: 1_000, status: "variance")
    @expense = @employee.employee_expenses.create!(incurred_on: Date.current - 2.days, merchant: "Amtrak", category: "travel", description: "Benefits implementation travel", amount_cents: 184_00, status: "submitted", receipt_status: "uploaded")
    @approved_expense = @employee.employee_expenses.create!(incurred_on: Date.current - 3.days, merchant: "Staples", category: "supplies", description: "Operations supplies", amount_cents: 86_00, status: "approved", receipt_status: "verified", approved_at: 1.day.ago)
    @blocked_expense = @employee.employee_expenses.create!(incurred_on: Date.current - 1.day, merchant: "Client services", category: "meals", description: "Team lunch missing receipt", amount_cents: 145_00, status: "submitted", receipt_status: "missing")
    time_start = @payroll_run.period_start_on.in_time_zone.change(hour: 9, min: 0)
    @approved_time_entry = @employee.time_entries.create!(work_date: @payroll_run.period_start_on, clock_in_at: time_start, clock_out_at: time_start + 8.hours, break_minutes: 30, source: "web", status: "approved", approved_at: 1.hour.ago, reviewed_at: 1.hour.ago, notes: "Regular shift")
    @submitted_time_entry = @employee.time_entries.create!(work_date: @payroll_run.period_start_on + 1.day, clock_in_at: time_start + 1.day, clock_out_at: time_start + 1.day + 9.hours, break_minutes: 45, source: "mobile", status: "submitted", notes: "Needs manager review")
    @lifecycle_event = @employee.employee_lifecycle_events.create!(
      event_type: "compensation_change",
      effective_on: Date.current + 14.days,
      summary: "Casey Ng base compensation adjustment for the next payroll period.",
      status: "draft",
      metadata: {
        changes: { compensation_cents: { from: 115_000_00, to: 122_000_00 } },
        payroll_impact: "pay_rate_update",
        benefits_impact: "none",
        compliance_impact: "none"
      }
    )
    @approved_lifecycle_event = @employee.employee_lifecycle_events.create!(
      event_type: "termination",
      effective_on: Date.current + 30.days,
      summary: "Casey Ng planned separation with final pay and benefits offboarding.",
      status: "approved",
      reviewed_at: 1.day.ago,
      metadata: {
        changes: { employment_status: { from: "active", to: "terminated" } },
        payroll_impact: "final_pay",
        benefits_impact: "end_coverage",
        compliance_impact: "cobra_review"
      }
    )
    @contractor = @employer.contractors.create!(
      first_name: "Devon",
      last_name: "Stone",
      email: "devon@example.com",
      business_name: "Stone Ops LLC",
      contractor_type: "company",
      status: "active",
      tax_form_status: "complete",
      payment_method_status: "verified",
      start_on: Date.current - 60.days,
      hourly_rate_cents: 8_500
    )
    @blocked_contractor = @employer.contractors.create!(
      first_name: "Rae",
      last_name: "Morgan",
      email: "rae@example.com",
      contractor_type: "individual",
      status: "onboarding",
      tax_form_status: "missing",
      payment_method_status: "missing",
      start_on: Date.current - 10.days,
      hourly_rate_cents: 6_000
    )
    @contractor_payment = @contractor.contractor_payments.create!(
      work_period_start_on: @payroll_run.period_start_on,
      work_period_end_on: @payroll_run.period_end_on,
      pay_date: @payroll_run.pay_date,
      description: "Benefits implementation support",
      amount_cents: 3_200_00,
      status: "draft"
    )
    @blocked_contractor_payment = @blocked_contractor.contractor_payments.create!(
      work_period_start_on: @payroll_run.period_start_on,
      work_period_end_on: @payroll_run.period_start_on + 7.days,
      pay_date: @payroll_run.pay_date,
      description: "Open onboarding support",
      amount_cents: 900_00,
      status: "draft"
    )
    @approved_contractor_tax_payment = @contractor.contractor_payments.create!(
      work_period_start_on: @payroll_run.period_start_on,
      work_period_end_on: @payroll_run.period_end_on,
      pay_date: @payroll_run.pay_date + 1.day,
      description: "Year-end implementation advisory",
      amount_cents: 1_250_00,
      status: "approved",
      approved_at: 1.day.ago
    )
    @employee.update!(metadata: @employee.metadata.to_h.merge(ssn_last4: "6789", tax_form_consent_status: "electronic_consented"))
    @contractor.update!(metadata: @contractor.metadata.to_h.merge(tin_last4: "4422", tax_form_consent_status: "electronic_consented"))
    @year_end_tax_form = @employer.year_end_tax_forms.create!(
      employee: @employee,
      tax_year: Date.current.year,
      form_type: "w2",
      recipient_name: @employee.full_name,
      recipient_email: @employee.email,
      tin_last4: "6789",
      jurisdiction: "Federal",
      gross_wages_cents: @pay_statement.gross_pay_cents,
      federal_withholding_cents: @pay_statement.tax_cents,
      state_withholding_cents: (@pay_statement.tax_cents * 0.18).round,
      benefit_reportable_cents: @pay_statement.deduction_cents,
      status: "ready",
      delivery_method: "employee_portal",
      consent_status: "electronic_consented",
      due_on: Date.new(Date.current.year + 1, 1, 31)
    )
    @contractor_year_end_tax_form = @employer.year_end_tax_forms.create!(
      contractor: @contractor,
      tax_year: Date.current.year,
      form_type: "1099_nec",
      recipient_name: @contractor.display_name,
      recipient_email: @contractor.email,
      tin_last4: nil,
      jurisdiction: "Federal",
      contractor_payment_cents: @approved_contractor_tax_payment.amount_cents,
      status: "ready",
      delivery_method: "contractor_portal",
      consent_status: "electronic_consented",
      due_on: Date.new(Date.current.year + 1, 1, 31)
    )
    @workers_comp_policy = @employer.workers_comp_policies.create!(
      carrier: "Pinnacol Assurance",
      policy_number: "WC-OPS-2026",
      status: "active",
      coverage_start_on: Date.current.beginning_of_year,
      coverage_end_on: Date.current.end_of_year,
      renewal_due_on: Date.current + 30.days,
      payroll_basis_cents: @employee.compensation_cents,
      manual_premium_cents: 2_875_00,
      deposit_premium_cents: 700_00,
      rate_basis_points: 250,
      contact_name: "Mara Wells",
      contact_email: "mara.wells@carrier.example"
    )
    @workers_comp_claim = @workers_comp_policy.workers_comp_claims.create!(
      employer: @employer,
      employee: @employee,
      claim_number: "WC-OPS-1001",
      incident_on: Date.current - 9.days,
      reported_on: Date.current - 8.days,
      status: "accepted",
      severity: "lost_time",
      injury_type: "strain",
      body_part: "Shoulder",
      description: "Employee reported a shoulder strain during workstation setup.",
      lost_time_days: 2,
      reserve_cents: 1_500_00,
      paid_cents: 250_00
    )
    @compliance_case = @employer.compliance_cases.create!(employee: @employee, kind: "i9_reverification", severity: "high", due_on: Date.current + 5.days)
    @compliance_notice = @employer.compliance_notices.create!(
      employee: @employee,
      source: "agency_mail",
      notice_type: "payroll_tax_deposit",
      title: "IRS deposit discrepancy notice",
      agency_name: "Internal Revenue Service",
      jurisdiction: "Federal",
      reference_number: "IRS-CP-276-OPS",
      severity: "high",
      status: "received",
      received_on: Date.current - 3.days,
      due_on: Date.current + 7.days,
      amount_cents: 1_250_00,
      response_owner: "Finance",
      response_channel: "agency_portal",
      summary: "Agency notice flags payroll tax deposit variance."
    )
    @response_ready_notice = @employer.compliance_notices.create!(
      employee: @employee,
      source: "state_portal",
      notice_type: "wage_hour",
      title: "Wage notice response",
      agency_name: "State Labor Department",
      jurisdiction: "CO",
      reference_number: "CO-WAGE-OPS",
      severity: "medium",
      status: "response_ready",
      received_on: Date.current - 4.days,
      due_on: Date.current + 3.days,
      amount_cents: 0,
      response_owner: "Compliance",
      response_channel: "secure_message",
      summary: "Wage-hour response is ready for submission."
    )
    @connection = @organization.integration_connections.create!(provider: "vitable", environment: "production", webhook_secret_reference: "VITABLE_WEBHOOK_SECRET")
    @sync_run = @connection.sync_runs.create!(
      resource_type: "employee",
      operation: "fetch",
      status: "failed",
      started_at: 5.minutes.ago,
      completed_at: 4.minutes.ago,
      error_message: "Missing credentials",
      stats: { resource_id: "empl_ops_123" }
    )
    @request_log = @connection.api_request_logs.create!(
      operation: "resource.fetch",
      method: "GET",
      path: "/employees/empl_ops_123",
      status_code: 401,
      duration_ms: 42,
      error_class: "VitableConnect::Errors::AuthenticationError",
      error_message: "Unauthorized"
    )
    @webhook_event = @connection.webhook_events.create!(
      event_id: "wevt_ops_eligibility_granted",
      organization_external_id: @organization.external_id,
      event_name: "employee.eligibility_granted",
      resource_type: "employee",
      resource_id: "empl_ops_123",
      occurred_at: Time.current,
      status: "needs_credentials",
      payload: {
        event_id: "wevt_ops_eligibility_granted",
        organization_id: @organization.external_id,
        event_name: "employee.eligibility_granted",
        resource_type: "employee",
        resource_id: "empl_ops_123",
        created_at: Time.current.iso8601
      }
    )
  end

  test "renders the expanded operations pages" do
    [
      root_path,
      company_setup_path,
      workforce_path,
      people_directory_path,
      hiring_path,
      employee_changes_path,
      performance_path,
      training_path,
      lifecycle_path,
      onboarding_path,
      documents_path,
      time_off_path,
      time_off_accruals_path,
      scheduling_path,
      timesheets_path,
      expenses_path,
      contractors_path,
      compensation_path,
      compensation_changes_path,
      taxes_path,
      tax_agency_registrations_path,
      payroll_deductions_center_path,
      payroll_calendar_path,
      payroll_funding_path,
      pay_statements_path,
      year_end_tax_forms_path,
      benefits_billing_path,
      reports_path,
      payroll_path,
      payroll_run_path(@payroll_run),
      payroll_run_benefits_export_path(@payroll_run),
      payroll_garnishments_path,
      benefits_path,
      benefits_plan_admin_path,
      benefits_open_enrollment_path,
      benefits_eligibility_path,
      benefits_dependent_verifications_path,
      benefits_offboarding_path,
      benefits_reconciliation_path,
      enrollment_path(@pending_enrollment),
      compliance_path,
      workers_comp_path,
      compliance_notices_path,
      integrations_path,
      vitable_employer_provisioning_path,
      vitable_census_sync_path,
      vitable_embedded_sessions_path,
      vitable_care_groups_path,
      integration_connection_path(@connection),
      webhook_event_path(@webhook_event),
      employee_path(@employee)
    ].each do |path|
      get path
      assert_response :success
    end
  end

  test "read side exposes DTOs instead of raw records" do
    dashboard = DashboardQuery.new.call
    company = Company::SetupQuery.new.call
    workforce = Operations::WorkforceQuery.new.call
    directory = People::DirectoryQuery.new.call
    hiring = Hiring::CenterQuery.new.call
    employee_changes = EmployeeChanges::CenterQuery.new.call
    performance = Performance::CenterQuery.new.call
    training = Training::CenterQuery.new.call
    lifecycle = Lifecycle::CommandCenterQuery.new.call
    payroll = Operations::PayrollQuery.new.call
    deductions = Deductions::CenterQuery.new.call
    garnishments = Garnishments::CenterQuery.new.call
    payroll_calendar = PayrollCalendar::CenterQuery.new.call
    onboarding = Onboarding::CommandCenterQuery.new.call
    documents = Documents::CenterQuery.new.call
    time_off = TimeOff::CommandCenterQuery.new.call
    pto_ledger = TimeOff::AccrualLedgerQuery.new.call
    scheduling = Scheduling::CenterQuery.new.call
    timesheets = TimeTracking::CenterQuery.new.call
    expenses = Expenses::CenterQuery.new.call
    funding = PayrollFunding::CenterQuery.new.call
    statements = PayStatements::CenterQuery.new.call
    year_end = YearEnd::TaxFormsQuery.new.call
    billing = Benefits::BillingQuery.new.call
    contractors = Contractors::CenterQuery.new.call
    compensation = Compensation::CenterQuery.new.call
    compensation_changes = Compensation::ChangesQuery.new.call
    taxes = Taxes::CenterQuery.new.call
    tax_registrations = Taxes::AgencyRegistrationsQuery.new.call
    reports = Reports::CenterQuery.new.call
    benefits = Operations::BenefitsQuery.new.call
    plan_admin = Benefits::PlanAdministrationQuery.new.call
    open_enrollment = OpenEnrollment::CenterQuery.new.call
    eligibility = Benefits::EligibilityQuery.new.call
    dependent_verifications = Benefits::DependentVerificationQuery.new.call
    offboarding = Benefits::OffboardingQuery.new.call
    reconciliation = Benefits::ReconciliationQuery.new.call
    compliance = Operations::ComplianceQuery.new.call
    workers_comp = WorkersComp::CenterQuery.new.call
    compliance_notices = Compliance::NoticeCenterQuery.new.call
    integrations = Operations::IntegrationsQuery.new.call
    employer_provisioning = Vitable::EmployerProvisioningQuery.new.call
    census = Vitable::CensusSyncQuery.new.call
    embedded_sessions = Vitable::EmbeddedSessionsQuery.new.call
    care_group = Vitable::CareGroupQuery.new.call

    assert_instance_of Employers::EmployerSummaryDto, dashboard.fetch(:employers).first
    assert_instance_of Dashboard::IntegrationHealthDto, dashboard.fetch(:integration_health)
    assert_instance_of Company::SetupDetailDto, company
    assert_instance_of Company::SetupStepDto, company.steps.first
    assert_instance_of Company::MetricDto, company.metrics.first
    assert_instance_of Operations::WorkforceEmployeeDto, workforce.fetch(:employees).first
    assert_instance_of People::DirectoryCenterDto, directory
    assert_instance_of People::MetricDto, directory.metrics.first
    assert_instance_of People::EmployeeNodeDto, directory.employees.first
    assert_instance_of People::DepartmentNodeDto, directory.departments.first
    assert_instance_of People::DirectoryIssueDto, directory.issues.first
    assert_instance_of Hiring::CenterDto, hiring
    assert_instance_of Hiring::MetricDto, hiring.metrics.first
    assert_instance_of Hiring::JobOpeningDto, hiring.job_openings.first
    assert_instance_of Hiring::CandidateDto, hiring.candidates.first
    assert_instance_of Hiring::PipelineStageDto, hiring.pipeline_stages.first
    assert_instance_of Hiring::IssueDto, hiring.issues.first
    assert_instance_of EmployeeChanges::CenterDto, employee_changes
    assert_instance_of EmployeeChanges::MetricDto, employee_changes.metrics.first
    assert_instance_of EmployeeChanges::RequestDto, employee_changes.requests.first
    assert_instance_of EmployeeChanges::TypeSummaryDto, employee_changes.type_summaries.first
    assert_instance_of EmployeeChanges::ImpactItemDto, employee_changes.impact_items.first
    assert_instance_of Performance::CenterDto, performance
    assert_instance_of Performance::MetricDto, performance.metrics.first
    assert_instance_of Performance::CycleDto, performance.cycles.first
    assert_instance_of Performance::ReviewDto, performance.reviews.first
    assert_instance_of Performance::GoalDto, performance.goals.first
    assert_instance_of Performance::IssueDto, performance.issues.first
    assert_instance_of Training::CenterDto, training
    assert_instance_of Training::MetricDto, training.metrics.first
    assert_instance_of Training::ProgramDto, training.programs.first
    assert_instance_of Training::AssignmentDto, training.assignments.first
    assert_instance_of Training::IssueDto, training.issues.first
    assert_instance_of Lifecycle::CenterDto, lifecycle
    assert_instance_of Lifecycle::MetricDto, lifecycle.metrics.first
    assert_instance_of Lifecycle::EventDto, lifecycle.events.first
    assert_instance_of Lifecycle::ImpactItemDto, lifecycle.impact_items.first
    assert_instance_of Deductions::CenterDto, deductions
    assert_instance_of Deductions::MetricDto, deductions.metrics.first
    assert_instance_of Deductions::PayrollRunDto, deductions.payroll_run
    assert_instance_of Deductions::DeductionDto, deductions.deductions.first
    assert_instance_of Deductions::IssueDto, deductions.issues.first
    assert_instance_of Garnishments::CenterDto, garnishments
    assert_instance_of Garnishments::MetricDto, garnishments.metrics.first
    assert_instance_of Garnishments::OrderDto, garnishments.orders.first
    assert_instance_of Garnishments::IssueDto, garnishments.issues.first
    assert_instance_of Operations::PayrollRunDto, payroll.fetch(:payroll_runs).first
    assert_instance_of PayrollCalendar::CenterDto, payroll_calendar
    assert_instance_of PayrollCalendar::MetricDto, payroll_calendar.metrics.first
    assert_instance_of PayrollCalendar::ScheduleDto, payroll_calendar.schedule
    assert_instance_of PayrollCalendar::RunDto, payroll_calendar.payroll_run
    assert_instance_of PayrollCalendar::ApprovalStepDto, payroll_calendar.approval_steps.first
    assert_instance_of PayrollCalendar::CalendarEventDto, payroll_calendar.calendar_events.first
    assert_instance_of PayrollCalendar::RiskDto, payroll_calendar.risks.first
    assert_instance_of Onboarding::CommandCenterDto, onboarding
    assert_instance_of Onboarding::EmployeeReadinessDto, onboarding.readiness.first
    assert_instance_of Onboarding::TaskDto, onboarding.tasks.first
    assert_instance_of Onboarding::DocumentDto, onboarding.documents.first
    assert_instance_of Onboarding::LaneDto, onboarding.lanes.first
    assert_instance_of Documents::CenterDto, documents
    assert_instance_of Documents::MetricDto, documents.metrics.first
    assert_instance_of Documents::DocumentDto, documents.documents.first
    assert_instance_of Documents::EmployeeCoverageDto, documents.employees.first
    assert_instance_of Documents::RequirementDto, documents.requirements.first
    assert_instance_of Documents::ExceptionDto, documents.exceptions.first
    assert_instance_of TimeOff::CommandCenterDto, time_off
    assert_instance_of TimeOff::RequestDto, time_off.requests.first
    assert_instance_of TimeOff::PolicyDto, time_off.policies.first
    assert_instance_of TimeOff::EmployeeBalanceDto, time_off.balances.first
    assert_instance_of TimeOff::AccrualCenterDto, pto_ledger
    assert_instance_of TimeOff::AccrualMetricDto, pto_ledger.metrics.first
    assert_instance_of TimeOff::AccrualBalanceDto, pto_ledger.balances.first
    assert_instance_of TimeOff::AccrualLineDto, pto_ledger.accruals.first
    assert_instance_of TimeOff::AccrualIssueDto, pto_ledger.issues.first
    assert_instance_of Scheduling::CenterDto, scheduling
    assert_instance_of Scheduling::MetricDto, scheduling.metrics.first
    assert_instance_of Scheduling::ShiftDto, scheduling.shifts.first
    assert_instance_of Scheduling::SwapRequestDto, scheduling.swap_requests.first
    assert_instance_of Scheduling::IssueDto, scheduling.issues.first
    assert_instance_of TimeTracking::CenterDto, timesheets
    assert_instance_of TimeTracking::EntryDto, timesheets.entries.first
    assert_instance_of TimeTracking::EmployeeSummaryDto, timesheets.employees.first
    assert_instance_of TimeTracking::DepartmentSummaryDto, timesheets.departments.first
    assert_instance_of TimeTracking::ExceptionDto, timesheets.exceptions.first
    assert_instance_of Expenses::CenterDto, expenses
    assert_instance_of Expenses::MetricDto, expenses.metrics.first
    assert_instance_of Expenses::ExpenseDto, expenses.expenses.first
    assert_instance_of Expenses::PolicyItemDto, expenses.policy_items.first
    assert_instance_of PayrollFunding::CenterDto, funding
    assert_instance_of PayrollFunding::MetricDto, funding.metrics.first
    assert_instance_of PayrollFunding::EmployerAccountDto, funding.employer_accounts.first
    assert_instance_of PayrollFunding::EmployeeAccountDto, funding.employee_accounts.first
    assert_instance_of PayrollFunding::RunFundingDto, funding.payroll_run
    assert_instance_of PayrollFunding::FundingIssueDto, funding.funding_issues.first
    assert_instance_of PayStatements::CenterDto, statements
    assert_instance_of PayStatements::MetricDto, statements.metrics.first
    assert_instance_of PayStatements::StatementDto, statements.statements.first
    assert_instance_of PayStatements::PayrollRunDto, statements.payroll_run
    assert_instance_of PayStatements::DeliveryIssueDto, statements.delivery_issues.first
    assert_instance_of YearEnd::CenterDto, year_end
    assert_instance_of YearEnd::MetricDto, year_end.metrics.first
    assert_instance_of YearEnd::TaxFormDto, year_end.forms.first
    assert_instance_of YearEnd::IssueDto, year_end.issues.first
    assert_instance_of Benefits::BillingCenterDto, billing
    assert_instance_of Benefits::BillingMetricDto, billing.metrics.first
    assert_instance_of Benefits::BillingInvoiceDto, billing.invoices.first
    assert_instance_of Benefits::BillingLineDto, billing.lines.first
    assert_instance_of Benefits::BillingVarianceDto, billing.variances.first
    assert_instance_of Contractors::CenterDto, contractors
    assert_instance_of Contractors::MetricDto, contractors.metrics.first
    assert_instance_of Contractors::ContractorDto, contractors.contractors.first
    assert_instance_of Contractors::PaymentDto, contractors.payments.first
    assert_instance_of Contractors::ReadinessItemDto, contractors.readiness_items.first
    assert_instance_of Compensation::CenterDto, compensation
    assert_instance_of Compensation::EmployeeCompensationDto, compensation.employees.first
    assert_instance_of Compensation::DepartmentBudgetDto, compensation.departments.first
    assert_instance_of Compensation::AdjustmentDto, compensation.adjustments.first
    assert_instance_of Compensation::RecommendationDto, compensation.recommendations.first
    assert_instance_of Compensation::ChangeCenterDto, compensation_changes
    assert_instance_of Compensation::ChangeDto, compensation_changes.changes.first
    assert_instance_of Compensation::MetricDto, compensation_changes.metrics.first
    assert_instance_of Taxes::CenterDto, taxes
    assert_instance_of Taxes::AgencyAccountDto, taxes.agency_accounts.first
    assert_instance_of Taxes::PayrollLiabilityDto, taxes.liabilities.first
    assert_instance_of Taxes::FilingCalendarItemDto, taxes.filing_calendar.first
    assert_instance_of Taxes::JurisdictionExposureDto, taxes.jurisdictions.first
    assert_instance_of Taxes::AgencyRegistrationCenterDto, tax_registrations
    assert_instance_of Taxes::AgencyRegistrationMetricDto, tax_registrations.metrics.first
    assert_instance_of Taxes::AgencyRegistrationDto, tax_registrations.registrations.first
    assert_instance_of Taxes::AgencyRegistrationIssueDto, tax_registrations.issues.first
    assert_instance_of Reports::CenterDto, reports
    assert_instance_of Reports::MetricDto, reports.metrics.first
    assert_instance_of Reports::ReportCardDto, reports.report_cards.first
    assert_instance_of Operations::BenefitPlanDto, benefits.fetch(:benefit_plans).first
    assert_instance_of Benefits::PlanAdministrationCenterDto, plan_admin
    assert_instance_of Benefits::PlanAdminMetricDto, plan_admin.metrics.first
    assert_instance_of Benefits::PlanDesignDto, plan_admin.plans.first
    assert_instance_of Benefits::PlanReadinessIssueDto, plan_admin.issues.first
    assert_instance_of OpenEnrollment::CenterDto, open_enrollment
    assert_instance_of OpenEnrollment::MetricDto, open_enrollment.metrics.first
    assert_instance_of OpenEnrollment::CampaignDto, open_enrollment.campaign
    assert_instance_of OpenEnrollment::InvitationDto, open_enrollment.invitations.first
    assert_instance_of OpenEnrollment::PlanReadinessDto, open_enrollment.plans.first
    assert_instance_of OpenEnrollment::IssueDto, open_enrollment.issues.first
    assert_instance_of Benefits::EligibilityCenterDto, eligibility
    assert_instance_of Benefits::EligibilityMetricDto, eligibility.metrics.first
    assert_instance_of Benefits::EligibilityMemberDto, eligibility.members.first
    assert_instance_of Benefits::EligibilityDependentDto, eligibility.dependents.first
    assert_instance_of Benefits::EligibilityIssueDto, eligibility.issues.first
    assert_instance_of Benefits::DependentVerificationCenterDto, dependent_verifications
    assert_instance_of Benefits::DependentVerificationMetricDto, dependent_verifications.metrics.first
    assert_instance_of Benefits::DependentVerificationDependentDto, dependent_verifications.dependents.first
    assert_instance_of Benefits::DependentVerificationRecordDto, dependent_verifications.verifications.first
    assert_instance_of Benefits::DependentVerificationIssueDto, dependent_verifications.issues.first
    assert_instance_of Benefits::OffboardingCenterDto, offboarding
    assert_instance_of Benefits::OffboardingMetricDto, offboarding.metrics.first
    assert_instance_of Benefits::OffboardingEventDto, offboarding.events.first
    assert_instance_of Benefits::OffboardingCoverageLineDto, offboarding.coverage_lines.first
    assert_instance_of Benefits::OffboardingIssueDto, offboarding.issues.first
    assert_instance_of Benefits::ReconciliationDetailDto, reconciliation
    assert_instance_of Operations::ComplianceCaseDto, compliance.fetch(:cases).first
    assert_instance_of WorkersComp::CenterDto, workers_comp
    assert_instance_of WorkersComp::MetricDto, workers_comp.metrics.first
    assert_instance_of WorkersComp::PolicyDto, workers_comp.policy
    assert_instance_of WorkersComp::ExposureDto, workers_comp.exposures.first
    assert_instance_of WorkersComp::ClaimDto, workers_comp.claims.first
    assert_instance_of WorkersComp::IssueDto, workers_comp.issues.first
    assert_instance_of Compliance::NoticeCenterDto, compliance_notices
    assert_instance_of Compliance::NoticeMetricDto, compliance_notices.metrics.first
    assert_instance_of Compliance::NoticeDto, compliance_notices.notices.first
    assert_instance_of Compliance::NoticeIssueDto, compliance_notices.issues.first
    assert_instance_of Operations::IntegrationConnectionDto, integrations.fetch(:connections).first
    assert_instance_of Vitable::EmployerProvisioningCenterDto, employer_provisioning
    assert_instance_of Vitable::EmployerProvisioningMetricDto, employer_provisioning.metrics.first
    assert_instance_of Vitable::EmployerProvisioningPreflightCheckDto, employer_provisioning.preflight_checks.first
    assert_instance_of Vitable::EmployerProvisioningPayloadDto, employer_provisioning.payload
    assert_instance_of Vitable::CensusSyncCenterDto, census
    assert_instance_of Vitable::CensusSyncMetricDto, census.metrics.first
    assert_instance_of Vitable::CensusSyncPreflightCheckDto, census.preflight_checks.first
    assert_instance_of Vitable::EmbeddedSessionsCenterDto, embedded_sessions
    assert_instance_of Vitable::EmbeddedSessionMetricDto, embedded_sessions.metrics.first
    assert_instance_of Vitable::EmbeddedSessionPreflightCheckDto, embedded_sessions.preflight_checks.first
    assert_instance_of Vitable::CareGroupCenterDto, care_group
    assert_instance_of Vitable::CareGroupMetricDto, care_group.metrics.first
    assert_instance_of Vitable::CareGroupPreflightCheckDto, care_group.preflight_checks.first
  end

  test "reports workspace exposes finance and risk DTOs" do
    detail = Reports::CenterQuery.new.call

    assert_instance_of Reports::CenterDto, detail
    assert_instance_of Reports::MetricDto, detail.metrics.first
    assert_instance_of Reports::ReportCardDto, detail.report_cards.first
    assert_instance_of Reports::DepartmentCostDto, detail.department_costs.first
    assert_instance_of Reports::BenefitSpendDto, detail.benefit_spend.first
    assert_instance_of Reports::RiskItemDto, detail.risk_items.first
    assert_equal @department.name, detail.department_costs.first.department_name

    get reports_path

    assert_response :success
    assert_select "h1", "Reports"
    assert_select "h2", "Report library"
    assert_select "h2", "Department cost ledger"
    assert_select "h2", "Benefits spend"
    assert_select "h2", "Risk register"
  end

  test "compensation center exposes pay planning DTOs" do
    detail = Compensation::CenterQuery.new.call

    assert_instance_of Compensation::CenterDto, detail
    assert_instance_of Compensation::MetricDto, detail.metrics.first
    assert_instance_of Compensation::EmployeeCompensationDto, detail.employees.first
    assert_instance_of Compensation::DepartmentBudgetDto, detail.departments.first
    assert_instance_of Compensation::AdjustmentDto, detail.adjustments.first
    assert_instance_of Compensation::RecommendationDto, detail.recommendations.first
    assert_equal @employee.full_name, detail.employees.first.employee_name
    assert_equal @department.name, detail.departments.first.department_name

    get compensation_path

    assert_response :success
    assert_select "h1", "Compensation planning center"
    assert_select "h2", "Department budget exposure"
    assert_select "h2", "Employee compensation"
    assert_select "h2", "Adjustment review"
    assert_select "h2", "Planning recommendations"
  end

  test "generates a compensation packet through command action" do
    post generate_compensation_packet_path

    assert_redirected_to compensation_path
    packet = @employer.reload.settings.fetch("compensation_packet")
    assert_match(/\Acomp_review_#{@employer.id}_/, packet.fetch("packet_id"))
    assert_equal "ops_console", packet.fetch("requested_by")
    assert_equal 1, packet.fetch("totals").fetch("employee_count")
    assert_equal @employee.compensation_cents, packet.fetch("totals").fetch("annual_compensation_cents")
    assert_equal @payroll_adjustment.amount_cents, packet.fetch("totals").fetch("adjustment_cents")
    assert_instance_of Array, packet.fetch("recommendations")
  end

  test "compensation changes center exposes pay change DTOs" do
    detail = Compensation::ChangesQuery.new.call

    assert_instance_of Compensation::ChangeCenterDto, detail
    assert_instance_of Compensation::MetricDto, detail.metrics.first
    assert_instance_of Compensation::ChangeDto, detail.changes.first
    assert detail.reviewable_changes.any? { |change| change.id == @submitted_compensation_change.id }
    assert detail.approved_changes.any? { |change| change.id == @approved_compensation_change.id }

    get compensation_changes_path

    assert_response :success
    assert_select "h1", "Compensation change management"
    assert_select "h2", "Review queue"
    assert_select "h2", "Approved changes"
    assert_select "h2", "Change ledger"
    assert_select "h2", "Payroll packet lines"
    assert_select "h2", "Packet holdbacks"
  end

  test "approves compensation change through command action" do
    post approve_compensation_change_path(@submitted_compensation_change), params: { approved_by: "finance_admin" }

    assert_redirected_to compensation_changes_path
    @submitted_compensation_change.reload
    assert_equal "approved", @submitted_compensation_change.status
    assert_equal "finance_admin", @submitted_compensation_change.approved_by
    assert_not_nil @submitted_compensation_change.approved_at
  end

  test "rejects compensation change through command action" do
    post reject_compensation_change_path(@rejectable_compensation_change), params: { reviewed_by: "finance_admin", reason: "Leveling is incomplete" }

    assert_redirected_to compensation_changes_path
    @rejectable_compensation_change.reload
    assert_equal "rejected", @rejectable_compensation_change.status
    assert_equal "finance_admin", @rejectable_compensation_change.rejected_by
    assert_equal "Leveling is incomplete", @rejectable_compensation_change.rejection_reason
  end

  test "applies approved base compensation change through command action" do
    post apply_compensation_change_path(@approved_compensation_change), params: { applied_by: "payroll_admin" }

    assert_redirected_to compensation_changes_path
    @approved_compensation_change.reload
    assert_equal "applied", @approved_compensation_change.status
    assert_equal "payroll_admin", @approved_compensation_change.applied_by
    assert_equal @approved_compensation_change.proposed_compensation_cents, @employee.reload.compensation_cents
  end

  test "applies one-time compensation change as payroll adjustment" do
    assert_difference -> { @payroll_run.payroll_adjustments.count }, 1 do
      post apply_compensation_change_path(@bonus_compensation_change), params: { applied_by: "payroll_admin" }
    end

    assert_redirected_to compensation_changes_path
    adjustment = @payroll_run.payroll_adjustments.order(:created_at).last
    assert_equal "one_time_bonus", adjustment.adjustment_type
    assert_equal @bonus_compensation_change.delta_cents, adjustment.amount_cents
    assert_equal "applied", @bonus_compensation_change.reload.status
  end

  test "generates compensation change payroll packet" do
    post generate_compensation_change_packet_path, params: { requested_by: "finance_admin" }

    assert_redirected_to compensation_changes_path
    packet = @employer.reload.settings.fetch("compensation_change_packet")
    assert_match(/\Acomp_changes_#{@employer.id}_/, packet.fetch("packet_id"))
    assert_equal "finance_admin", packet.fetch("requested_by")
    assert_equal 2, packet.fetch("totals").fetch("change_count")
    assert_equal 1, packet.fetch("totals").fetch("employee_count")
    assert_equal @approved_compensation_change.delta_cents, packet.fetch("totals").fetch("recurring_delta_cents")
    assert_equal @bonus_compensation_change.delta_cents, packet.fetch("totals").fetch("one_time_cents")
    assert_equal 2, packet.fetch("totals").fetch("holdback_count")

    detail = Compensation::ChangesQuery.new.call
    assert_instance_of Compensation::ChangePacketDto, detail.packet
    assert_instance_of Compensation::ChangePacketLineDto, detail.packet_lines.first
    assert_instance_of Compensation::ChangePacketHoldbackDto, detail.packet_holdbacks.first
  end

  test "tax filings center exposes agency and liability DTOs" do
    detail = Taxes::CenterQuery.new.call

    assert_instance_of Taxes::CenterDto, detail
    assert_instance_of Taxes::MetricDto, detail.metrics.first
    assert_instance_of Taxes::AgencyAccountDto, detail.agency_accounts.first
    assert_instance_of Taxes::FilingCalendarItemDto, detail.filing_calendar.first
    assert_instance_of Taxes::PayrollLiabilityDto, detail.liabilities.first
    assert_instance_of Taxes::JurisdictionExposureDto, detail.jurisdictions.first
    assert_instance_of Taxes::RecommendationDto, detail.recommendations.first
    assert_equal @payroll_run.id, detail.liabilities.first.payroll_run_id

    get taxes_path

    assert_response :success
    assert_select "h1", "Tax filings center"
    assert_select "h2", "Agency accounts"
    assert_select "h2", "Filing calendar"
    assert_select "h2", "Payroll tax liabilities"
    assert_select "h2", "Jurisdiction exposure"
    assert_select "h2", "Readiness recommendations"
  end

  test "generates a tax filing packet through command action" do
    post generate_tax_filing_packet_path

    assert_redirected_to taxes_path
    packet = @employer.reload.settings.fetch("tax_filing_packet")
    assert_match(/\Atax_filing_#{@employer.id}_/, packet.fetch("packet_id"))
    assert_equal "ops_console", packet.fetch("requested_by")
    assert_equal 1, packet.fetch("totals").fetch("payroll_run_count")
    assert_equal @payroll_run.gross_pay_cents, packet.fetch("totals").fetch("gross_pay_cents")
    assert packet.fetch("totals").fetch("total_liability_cents").positive?
    assert_instance_of Array, packet.fetch("agency_accounts")
    assert_instance_of Array, packet.fetch("recommendations")
  end

  test "tax agency registrations center exposes registration DTOs" do
    detail = Taxes::AgencyRegistrationsQuery.new.call

    assert_instance_of Taxes::AgencyRegistrationCenterDto, detail
    assert_instance_of Taxes::AgencyRegistrationMetricDto, detail.metrics.first
    assert_instance_of Taxes::AgencyRegistrationDto, detail.registrations.first
    assert_instance_of Taxes::AgencyRegistrationIssueDto, detail.issues.first
    assert detail.registrations.any? { |registration| registration.id == @tax_registration.id }

    get tax_agency_registrations_path

    assert_response :success
    assert_select "h1", "Tax agency registrations"
    assert_select "h2", "Registration queue"
    assert_select "h2", "Registration blockers"
    assert_select "h2", "Jurisdiction registration matrix"
    assert_select "h2", "Packet registration lines"
    assert_select "h2", "Packet holdbacks"
  end

  test "submits a tax agency registration through command action" do
    post submit_tax_agency_registration_path(@tax_registration), params: { submitted_by: "tax_ops", confirmation_number: "REMOTE-SUB-42" }

    assert_redirected_to tax_agency_registrations_path
    @tax_registration.reload
    assert_equal "submitted", @tax_registration.status
    assert_equal "REMOTE-SUB-42", @tax_registration.confirmation_number
    assert_equal "tax_ops", @tax_registration.metadata.fetch("submitted_by")
    assert_not_nil @tax_registration.submitted_at
  end

  test "generates a tax agency registration packet through command action" do
    post generate_tax_agency_registration_packet_path, params: { requested_by: "tax_ops" }

    assert_redirected_to tax_agency_registrations_path
    packet = @employer.reload.settings.fetch("tax_agency_registration_packet")
    assert_match(/\Atax_registration_#{@employer.id}_/, packet.fetch("packet_id"))
    assert_equal "tax_ops", packet.fetch("requested_by")
    assert_equal 2, packet.fetch("totals").fetch("registration_count")
    assert_equal 1, packet.fetch("totals").fetch("submitted_count")
    assert_equal 1, packet.fetch("totals").fetch("ready_count")
    assert packet.fetch("totals").fetch("holdback_count").positive?

    detail = Taxes::AgencyRegistrationsQuery.new.call
    assert_instance_of Taxes::AgencyRegistrationPacketDto, detail.packet
    assert_instance_of Taxes::AgencyRegistrationPacketLineDto, detail.packet_lines.first
    assert_instance_of Taxes::AgencyRegistrationIssueDto, detail.packet_holdbacks.first
  end

  test "generates a reports snapshot through command action" do
    post generate_reports_snapshot_path

    assert_redirected_to reports_path
    snapshot = @employer.reload.settings.fetch("report_snapshot")
    assert_match(/\Aops_reports_#{@employer.id}_/, snapshot.fetch("snapshot_id"))
    assert_equal "ops_console", snapshot.fetch("requested_by")
    assert_equal 1, snapshot.fetch("metrics").fetch("active_employee_count")
    assert_equal 4, snapshot.fetch("exports").count
  end

  test "company setup center exposes launch readiness DTOs" do
    detail = Company::SetupQuery.new.call

    assert_instance_of Company::SetupDetailDto, detail
    assert_instance_of Company::MetricDto, detail.metrics.first
    assert_instance_of Company::SetupStepDto, detail.steps.first
    assert_instance_of Company::PayrollSettingDto, detail.payroll_settings.first
    assert_instance_of Company::OrgUnitDto, detail.departments.first
    assert_instance_of Company::LocationCoverageDto, detail.locations.first
    assert_instance_of Company::IntegrationReadinessDto, detail.integration
    assert detail.steps.any? { |step| step.key == "launch_review" }

    get company_setup_path

    assert_response :success
    assert_select "h1", "Company setup center"
    assert_select "h2", "Launch checklist"
    assert_select "h2", "Legal entity and payroll settings"
    assert_select "h2", "Org structure"
    assert_select "h2", "Vitable readiness"
    assert_select "h2", "Coverage summary"
  end

  test "completes a company setup checkpoint through command action" do
    post complete_company_setup_step_path("launch_review")

    assert_redirected_to company_setup_path
    @employer.reload
    step = @employer.settings.fetch("setup_steps").fetch("launch_review")
    assert_equal "ops_console", step.fetch("completed_by")
    assert_not_nil step.fetch("completed_at")
  end

  test "people directory center exposes org chart DTOs" do
    manager, unassigned_report = create_directory_manager_pair

    detail = People::DirectoryQuery.new.call

    assert_instance_of People::DirectoryCenterDto, detail
    assert_instance_of People::MetricDto, detail.metrics.first
    assert_instance_of People::EmployeeNodeDto, detail.employees.first
    assert_instance_of People::ManagerSpanDto, detail.managers.first
    assert_instance_of People::DepartmentNodeDto, detail.departments.first
    assert_instance_of People::DirectoryIssueDto, detail.issues.first
    assert detail.managers.any? { |span| span.manager_id == manager.id }
    assert detail.unassigned_employees.any? { |employee| employee.employee_id == unassigned_report.id }
    assert detail.issues.any? { |issue| issue.employee_id == unassigned_report.id }

    get people_directory_path

    assert_response :success
    assert_select "h1", "People directory and org chart"
    assert_select "h2", "Manager spans"
    assert_select "h2", "Org hygiene issues"
    assert_select "h2", "Employee directory"
    assert_select "h2", "Manager assignment queue"
    assert_select "h2", "Departments"
    assert_select "h2", "Snapshot issues"
  end

  test "assigns manager through command action" do
    manager, unassigned_report = create_directory_manager_pair

    dto = People::AssignManagerDto.from_params(employee_id: unassigned_report.id, manager_id: manager.id, assigned_by: "people_ops_admin")

    assert_equal unassigned_report.id, dto.employee_id
    assert_equal manager.id, dto.manager_id
    assert_equal "people_ops_admin", dto.assigned_by

    post assign_people_manager_path(unassigned_report.id, manager.id), params: { assigned_by: "people_ops_admin" }

    assert_redirected_to people_directory_path
    unassigned_report.reload
    assert_equal manager, unassigned_report.manager
    assert_equal "people_ops_admin", unassigned_report.metadata.fetch("manager_assigned_by")
    assert_equal "people_directory", unassigned_report.metadata.fetch("manager_assignment_source")
    assert_not_nil unassigned_report.metadata.fetch("manager_assigned_at")
  end

  test "generates people directory snapshot through command action" do
    _manager, unassigned_report = create_directory_manager_pair

    dto = People::GenerateDirectorySnapshotDto.from_params(requested_by: "people_ops_admin")

    assert_equal "people_ops_admin", dto.requested_by

    post generate_people_directory_snapshot_path, params: { requested_by: "people_ops_admin" }

    assert_redirected_to people_directory_path
    snapshot = @employer.reload.settings.fetch("people_directory_snapshot")
    assert_match(/\Apeople_directory_#{@employer.id}_/, snapshot.fetch("snapshot_id"))
    assert_equal "people_ops_admin", snapshot.fetch("requested_by")
    assert_equal @employer.employees.active.count, snapshot.fetch("totals").fetch("employee_count")
    assert_equal 1, snapshot.fetch("totals").fetch("manager_count")
    assert_equal 1, snapshot.fetch("totals").fetch("unassigned_count")
    assert snapshot.fetch("issues").any? { |issue| issue.fetch("employee_id") == unassigned_report.id }

    detail = People::DirectoryQuery.new.call

    assert_instance_of People::DirectorySnapshotDto, detail.snapshot
    assert_instance_of People::DirectoryIssueDto, detail.snapshot_issues.first
    assert_equal snapshot.fetch("snapshot_id"), detail.snapshot.snapshot_id
  end

  test "hiring center exposes offer pipeline DTOs" do
    detail = Hiring::CenterQuery.new.call

    assert_instance_of Hiring::CenterDto, detail
    assert_instance_of Hiring::MetricDto, detail.metrics.first
    assert_instance_of Hiring::JobOpeningDto, detail.job_openings.first
    assert_instance_of Hiring::CandidateDto, detail.candidates.first
    assert_instance_of Hiring::PipelineStageDto, detail.pipeline_stages.first
    assert_instance_of Hiring::IssueDto, detail.issues.first
    assert detail.offerable_candidates.any? { |candidate| candidate.id == @offerable_candidate.id }
    assert detail.accepted_candidates.any? { |candidate| candidate.id == @accepted_candidate.id }

    get hiring_path

    assert_response :success
    assert_select "h1", "Hiring and offers"
    assert_select "h2", "Pipeline stages"
    assert_select "h2", "Hiring issues"
    assert_select "h2", "Open roles"
    assert_select "h2", "Candidate pipeline"
    assert_select "h2", "Onboarding handoff ledger"
  end

  test "sends a candidate offer through command action" do
    post send_candidate_offer_path(@offerable_candidate), params: { offered_by: "recruiting_admin" }

    assert_redirected_to hiring_path
    @offerable_candidate.reload
    assert_equal "offer", @offerable_candidate.stage
    assert_equal "recruiting_admin", @offerable_candidate.metadata.fetch("offered_by")
    assert_equal "candidate_portal", @offerable_candidate.metadata.fetch("offer_channel")
    assert_not_nil @offerable_candidate.offer_sent_at
  end

  test "generates hiring onboarding handoff through command action" do
    post generate_hiring_onboarding_handoff_path, params: { requested_by: "people_ops_admin" }

    assert_redirected_to hiring_path
    @accepted_candidate.reload
    employee = @accepted_candidate.employee
    batch = @employer.reload.settings.fetch("hiring_onboarding_handoff")

    assert_equal "hired", @accepted_candidate.stage
    assert_not_nil @accepted_candidate.hired_at
    assert_not_nil employee
    assert_equal @accepted_candidate.email, employee.email
    assert_equal "in_progress", employee.onboarding_status
    assert_equal 4, employee.onboarding_tasks.count
    assert_match(/\Ahiring_onboarding_#{@employer.id}_/, batch.fetch("batch_id"))
    assert_equal "people_ops_admin", batch.fetch("requested_by")
    assert_equal 1, batch.fetch("totals").fetch("hire_count")
    assert_equal 4, batch.fetch("totals").fetch("task_count")

    detail = Hiring::CenterQuery.new.call
    assert_instance_of Hiring::HandoffBatchDto, detail.latest_handoff_batch
    assert_instance_of Hiring::HandoffLineDto, detail.handoff_lines.first

    post generate_hiring_onboarding_handoff_path

    assert_redirected_to hiring_path
    holdback_detail = Hiring::CenterQuery.new.call
    assert_instance_of Hiring::HandoffHoldbackDto, holdback_detail.handoff_holdbacks.first
  end

  test "employee self-service inbox exposes request DTOs" do
    detail = EmployeeChanges::CenterQuery.new.call

    assert_instance_of EmployeeChanges::CenterDto, detail
    assert_instance_of EmployeeChanges::MetricDto, detail.metrics.first
    assert_instance_of EmployeeChanges::RequestDto, detail.requests.first
    assert_instance_of EmployeeChanges::TypeSummaryDto, detail.type_summaries.first
    assert_instance_of EmployeeChanges::ImpactItemDto, detail.impact_items.first
    assert detail.reviewable_requests.any? { |request| request.id == @direct_deposit_change_request.id }
    assert detail.applied_requests.any? { |request| request.id == @applied_employee_change_request.id }

    get employee_changes_path

    assert_response :success
    assert_select "h1", "Employee self-service inbox"
    assert_select "h2", "Self-service lanes"
    assert_select "h2", "Review queue"
    assert_select "h2", "Impact checks"
    assert_select "h2", "Employee change ledger"
    assert_select "h2", "Profile sync ledger"
  end

  test "approves direct deposit employee change through command action" do
    post approve_employee_change_request_path(@direct_deposit_change_request), params: { reviewed_by: "payroll_admin" }

    assert_redirected_to employee_changes_path
    @direct_deposit_change_request.reload
    new_account = @employee.employee_bank_accounts.find_by(account_last4: "6204")

    assert_equal "applied", @direct_deposit_change_request.status
    assert_equal "payroll_admin", @direct_deposit_change_request.reviewed_by
    assert_not_nil @direct_deposit_change_request.applied_at
    assert_not_nil new_account
    assert_equal "prenote_sent", new_account.status
    assert new_account.primary_account?
    assert_equal @direct_deposit_change_request.id, new_account.metadata.fetch("employee_change_request_id")
    assert_not @employee_bank_account.reload.primary_account?
  end

  test "rejects employee change through command action" do
    post reject_employee_change_request_path(@profile_change_request), params: { reviewed_by: "people_ops_admin", reason: "Preferred name requires employee confirmation" }

    assert_redirected_to employee_changes_path
    @profile_change_request.reload
    assert_equal "rejected", @profile_change_request.status
    assert_equal "people_ops_admin", @profile_change_request.reviewed_by
    assert_equal "Preferred name requires employee confirmation", @profile_change_request.metadata.fetch("rejected_reason")
    assert_not_nil @profile_change_request.rejected_at
  end

  test "generates employee change profile sync batch through command action" do
    post generate_employee_changes_sync_batch_path, params: { requested_by: "integration_admin" }

    assert_redirected_to employee_changes_path
    batch = @employer.reload.settings.fetch("employee_change_sync_batch")
    assert_match(/\Aemployee_changes_#{@employer.id}_/, batch.fetch("batch_id"))
    assert_equal "integration_admin", batch.fetch("requested_by")
    assert_equal 1, batch.fetch("totals").fetch("request_count")
    assert_equal 1, batch.fetch("totals").fetch("employee_count")
    assert_equal 1, batch.fetch("totals").fetch("payroll_impact_count")
    assert_equal 2, batch.fetch("totals").fetch("holdback_count")
    assert_equal "sync_queued", @applied_employee_change_request.reload.status

    detail = EmployeeChanges::CenterQuery.new.call
    assert_instance_of EmployeeChanges::SyncBatchDto, detail.latest_batch
    assert_instance_of EmployeeChanges::SyncLineDto, detail.sync_lines.first
    assert_instance_of EmployeeChanges::SyncHoldbackDto, detail.sync_holdbacks.first
  end

  test "performance center exposes review and goal DTOs" do
    detail = Performance::CenterQuery.new.call

    assert_instance_of Performance::CenterDto, detail
    assert_instance_of Performance::MetricDto, detail.metrics.first
    assert_instance_of Performance::CycleDto, detail.cycles.first
    assert_instance_of Performance::ReviewDto, detail.reviews.first
    assert_instance_of Performance::GoalDto, detail.goals.first
    assert_instance_of Performance::IssueDto, detail.issues.first
    assert detail.calibratable_reviews.any? { |review| review.id == @manager_review.id }
    assert detail.open_goals.any? { |goal| goal.id == @at_risk_goal.id }

    get performance_path

    assert_response :success
    assert_select "h1", "Performance management center"
    assert_select "h2", "Cycle portfolio"
    assert_select "h2", "Performance issues"
    assert_select "h2", "Review queue"
    assert_select "h2", "Goal tracker"
    assert_select "h2", "Calibration packet ledger"
  end

  test "launches draft performance cycle through command action" do
    post launch_performance_cycle_path, params: { requested_by: "people_ops_admin" }

    assert_redirected_to performance_path
    @draft_performance_cycle.reload
    assert_equal "active", @draft_performance_cycle.status
    assert_equal "people_ops_admin", @draft_performance_cycle.metadata.fetch("launched_by")
    assert_not_nil @draft_performance_cycle.launched_at
    assert @draft_performance_cycle.performance_reviews.where(employee: @employee).exists?
  end

  test "calibrates performance review through command action" do
    post calibrate_performance_review_path(@manager_review), params: { calibrated_by: "calibration_admin" }

    assert_redirected_to performance_path
    @manager_review.reload
    assert_equal "complete", @manager_review.status
    assert_equal "calibration_admin", @manager_review.metadata.fetch("calibrated_by")
    assert_not_nil @manager_review.calibrated_at
    assert_not_nil @manager_review.completed_at
  end

  test "completes employee goal through command action" do
    post complete_employee_goal_path(@at_risk_goal), params: { reviewed_by: "manager_admin" }

    assert_redirected_to performance_path
    @at_risk_goal.reload
    assert_equal "complete", @at_risk_goal.status
    assert_equal 100, @at_risk_goal.progress_percent
    assert_equal "manager_admin", @at_risk_goal.metadata.fetch("completed_by")
    assert_not_nil @at_risk_goal.completed_at
  end

  test "generates performance calibration packet through command action" do
    post generate_performance_calibration_packet_path, params: { requested_by: "people_ops_admin" }

    assert_redirected_to performance_path
    batch = @employer.reload.settings.fetch("performance_calibration_packet")
    assert_match(/\Aperformance_calibration_#{@employer.id}_/, batch.fetch("batch_id"))
    assert_equal "people_ops_admin", batch.fetch("requested_by")
    assert_equal 1, batch.fetch("totals").fetch("review_count")
    assert_equal 1, batch.fetch("totals").fetch("employee_count")
    assert_equal 1, batch.fetch("totals").fetch("holdback_count")
    assert_equal "calibration", @manager_review.reload.status

    detail = Performance::CenterQuery.new.call
    assert_instance_of Performance::CalibrationBatchDto, detail.latest_batch
    assert_instance_of Performance::CalibrationLineDto, detail.calibration_lines.first
    assert_instance_of Performance::CalibrationHoldbackDto, detail.calibration_holdbacks.first
  end

  test "training center exposes program and assignment DTOs" do
    detail = Training::CenterQuery.new.call

    assert_instance_of Training::CenterDto, detail
    assert_instance_of Training::MetricDto, detail.metrics.first
    assert_instance_of Training::ProgramDto, detail.programs.first
    assert_instance_of Training::AssignmentDto, detail.assignments.first
    assert_instance_of Training::IssueDto, detail.issues.first
    assert detail.certificate_ready_assignments.any? { |assignment| assignment.id == @completed_training_assignment.id }
    assert detail.completable_assignments.any? { |assignment| assignment.id == @open_training_assignment.id }

    get training_path

    assert_response :success
    assert_select "h1", "Compliance training center"
    assert_select "h2", "Training portfolio"
    assert_select "h2", "Training issues"
    assert_select "h2", "Assignment roster"
    assert_select "h2", "Audit packet ledger"
  end

  test "launches draft training program through command action" do
    post launch_training_program_path, params: { requested_by: "people_ops_admin" }

    assert_redirected_to training_path
    @draft_training_program.reload
    assert_equal "active", @draft_training_program.status
    assert_equal "people_ops_admin", @draft_training_program.metadata.fetch("launched_by")
    assert_not_nil @draft_training_program.launched_at
    assert @draft_training_program.training_assignments.where(employee: @employee).exists?
  end

  test "completes training assignment through command action" do
    post complete_training_assignment_path(@open_training_assignment), params: { completed_by: "training_admin", score: 96 }

    assert_redirected_to training_path
    @open_training_assignment.reload
    assert_equal "complete", @open_training_assignment.status
    assert_equal 96, @open_training_assignment.score
    assert_equal "training_admin", @open_training_assignment.metadata.fetch("completed_by")
    assert_not_nil @open_training_assignment.completed_at
    assert_not_nil @open_training_assignment.certificate_id
  end

  test "generates training audit packet through command action" do
    post generate_training_audit_packet_path, params: { requested_by: "people_ops_admin" }

    assert_redirected_to training_path
    batch = @employer.reload.settings.fetch("training_audit_packet")
    assert_match(/\Atraining_audit_#{@employer.id}_/, batch.fetch("batch_id"))
    assert_equal "people_ops_admin", batch.fetch("requested_by")
    assert_equal 1, batch.fetch("totals").fetch("assignment_count")
    assert_equal 1, batch.fetch("totals").fetch("employee_count")
    assert_equal 1, batch.fetch("totals").fetch("holdback_count")
    assert_equal @completed_training_assignment.id, batch.fetch("assignments").first.fetch("assignment_id")

    detail = Training::CenterQuery.new.call
    assert_instance_of Training::AuditPacketDto, detail.latest_packet
    assert_instance_of Training::AuditLineDto, detail.audit_lines.first
    assert_instance_of Training::AuditHoldbackDto, detail.audit_holdbacks.first
  end

  test "lifecycle workspace exposes employee change DTOs" do
    detail = Lifecycle::CommandCenterQuery.new.call

    assert_instance_of Lifecycle::CenterDto, detail
    assert_instance_of Lifecycle::MetricDto, detail.metrics.first
    assert_instance_of Lifecycle::EventDto, detail.events.first
    assert_instance_of Lifecycle::ImpactItemDto, detail.impact_items.first
    assert detail.pending_events.any? { |event| event.id == @lifecycle_event.id }
    assert detail.approved_events.any? { |event| event.id == @approved_lifecycle_event.id }

    get lifecycle_path

    assert_response :success
    assert_select "h1", "Employee lifecycle"
    assert_select "h2", "Lifecycle review queue"
    assert_select "h2", "Lifecycle impact checks"
    assert_select "h2", "Employee change ledger"
    assert_select "h2", "Lifecycle sync ledger"
  end

  test "approves a lifecycle event through command action" do
    post approve_lifecycle_event_path(@lifecycle_event), params: { reviewed_by: "ops_console" }

    assert_redirected_to lifecycle_path
    @lifecycle_event.reload
    assert_equal "approved", @lifecycle_event.status
    assert_equal "ops_console", @lifecycle_event.metadata.fetch("reviewed_by")
    assert_not_nil @lifecycle_event.reviewed_at
  end

  test "generates a lifecycle sync batch through command action" do
    post generate_lifecycle_sync_batch_path

    assert_redirected_to lifecycle_path
    batch = @employer.reload.settings.fetch("lifecycle_sync_batch")
    assert_match(/\Alifecycle_sync_#{@employer.id}_/, batch.fetch("batch_id"))
    assert_equal "ops_console", batch.fetch("requested_by")
    assert_equal 1, batch.fetch("totals").fetch("event_count")
    assert_equal 1, batch.fetch("totals").fetch("employee_count")
    assert_equal 1, batch.fetch("totals").fetch("holdback_count")
    assert_equal 1, batch.fetch("totals").fetch("benefit_impact_count")
    assert_equal 1, batch.fetch("totals").fetch("payroll_impact_count")
    assert_equal @approved_lifecycle_event.id, batch.fetch("events").first.fetch("event_id")
    assert_equal "sync_queued", @approved_lifecycle_event.reload.status

    detail = Lifecycle::CommandCenterQuery.new.call
    assert_instance_of Lifecycle::SyncBatchDto, detail.latest_batch
    assert_instance_of Lifecycle::SyncLineDto, detail.batch_lines.first
    assert_instance_of Lifecycle::SyncHoldbackDto, detail.batch_holdbacks.first
  end

  test "onboarding workspace exposes readiness and review DTOs" do
    detail = Onboarding::CommandCenterQuery.new.call

    assert_instance_of Onboarding::CommandCenterDto, detail
    assert_instance_of Onboarding::CommandMetricDto, detail.metrics.first
    assert_instance_of Onboarding::EmployeeReadinessDto, detail.readiness.first
    assert_instance_of Onboarding::TaskDto, detail.tasks.first
    assert_instance_of Onboarding::DocumentDto, detail.documents.first
    assert detail.attention_documents.any? { |document| document.id == @pending_document.id }

    get onboarding_path

    assert_response :success
    assert_select "h1", "Onboarding"
    assert_select "h2", "Readiness lanes"
    assert_select "h2", "Employee readiness"
    assert_select "h2", "Task queue"
    assert_select "h2", "Document review"
  end

  test "verifies an employee document through the command action" do
    post verify_employee_document_path(@pending_document)

    assert_redirected_to onboarding_path
    @pending_document.reload
    assert_equal "complete", @pending_document.status
    assert_equal Date.current, @pending_document.issued_on
    assert_equal "ops_console", @pending_document.metadata.fetch("verified_by")
    assert_not_nil @pending_document.metadata.fetch("verified_at")
    assert_not_nil @pending_document.verified_at
  end

  test "document vault exposes coverage DTOs" do
    detail = Documents::CenterQuery.new.call

    assert_instance_of Documents::CenterDto, detail
    assert_instance_of Documents::MetricDto, detail.metrics.first
    assert_instance_of Documents::DocumentDto, detail.documents.first
    assert_instance_of Documents::EmployeeCoverageDto, detail.employees.first
    assert_instance_of Documents::RequirementDto, detail.requirements.first
    assert_instance_of Documents::ExceptionDto, detail.exceptions.first
    assert detail.attention_documents.any? { |document| document.id == @pending_document.id }

    get documents_path

    assert_response :success
    assert_select "h1", "Employee document vault"
    assert_select "h2", "Document exceptions"
    assert_select "h2", "Employee coverage"
    assert_select "h2", "Required document matrix"
    assert_select "h2", "Document ledger"
    assert_select "h2", "Request batch ledger"
  end

  test "generates employee document requests through command action" do
    post request_document_batch_path

    assert_redirected_to documents_path
    batch = @employer.reload.settings.fetch("document_request_batch")
    assert_match(/\Adocument_requests_#{@employer.id}_/, batch.fetch("batch_id"))
    assert_equal "ops_console", batch.fetch("requested_by")
    assert batch.fetch("totals").fetch("request_count").positive?
    assert batch.fetch("totals").fetch("employee_count").positive?
    assert @employee.employee_documents.where(title: "Form I-9", status: "requested").exists?

    detail = Documents::CenterQuery.new.call
    assert_instance_of Documents::BatchDto, detail.latest_batch
    assert_instance_of Documents::BatchLineDto, detail.batch_lines.first
    assert_instance_of Documents::BatchHoldbackDto, detail.batch_holdbacks.first
  end

  test "verifies an employee document from the document vault" do
    post verify_employee_document_path(@pending_document), params: { return_to: "documents", reviewed_by: "document_admin" }

    assert_redirected_to documents_path
    @pending_document.reload
    assert_equal "complete", @pending_document.status
    assert_equal "document_admin", @pending_document.metadata.fetch("verified_by")
    assert_equal "document_vault", @pending_document.metadata.fetch("verification_source")
    assert_not_nil @pending_document.verified_at
  end

  test "time off workspace exposes policies balances and calendar DTOs" do
    detail = TimeOff::CommandCenterQuery.new.call

    assert_instance_of TimeOff::CommandCenterDto, detail
    assert_instance_of TimeOff::MetricDto, detail.metrics.first
    assert_instance_of TimeOff::PolicyDto, detail.policies.first
    assert_instance_of TimeOff::EmployeeBalanceDto, detail.balances.first
    assert_instance_of TimeOff::RequestDto, detail.requests.first
    assert_instance_of TimeOff::CalendarBlockDto, detail.calendar_blocks.first
    assert detail.pending_requests.any? { |request| request.id == @time_off_request.id }

    get time_off_path

    assert_response :success
    assert_select "h1", "Time off"
    assert_select "h2", "Request review"
    assert_select "h2", "Employee balances"
    assert_select "h2", "Policy utilization"
    assert_select "h2", "Upcoming leave calendar"
  end

  test "approves a time off request from the time off workspace" do
    post approve_time_off_request_path(@time_off_request), params: { return_to: "time_off" }

    assert_redirected_to time_off_path
    @time_off_request.reload
    assert_equal "approved", @time_off_request.status
    assert_equal "time_off_command_center", @time_off_request.metadata.fetch("reviewed_from")
    assert_equal "approved", @time_off_request.metadata.fetch("review_decision")
    assert_not_nil @time_off_request.reviewed_at
  end

  test "PTO accrual ledger exposes balances and packet DTOs" do
    detail = TimeOff::AccrualLedgerQuery.new.call

    assert_instance_of TimeOff::AccrualCenterDto, detail
    assert_instance_of TimeOff::AccrualMetricDto, detail.metrics.first
    assert_instance_of TimeOff::AccrualBalanceDto, detail.balances.first
    assert_instance_of TimeOff::AccrualLineDto, detail.accruals.first
    assert_instance_of TimeOff::AccrualIssueDto, detail.issues.first
    assert detail.pending_accruals.any? { |accrual| accrual.id == @time_off_accrual.id }

    get time_off_accruals_path

    assert_response :success
    assert_select "h1", "PTO accrual and payroll ledger"
    assert_select "h2", "Employee PTO balances"
    assert_select "h2", "Payroll readiness issues"
    assert_select "h2", "Accrual ledger"
    assert_select "h2", "Payroll packet lines"
    assert_select "h2", "Packet holdbacks"
  end

  test "generates monthly PTO accruals through command action" do
    dto = TimeOff::GenerateAccrualRunDto.from_params(period_start_on: Date.current.beginning_of_month.iso8601, requested_by: "payroll_admin")

    assert_equal Date.current.beginning_of_month, dto.period_start_on
    assert_equal "payroll_admin", dto.requested_by

    assert_difference -> { TimeOffAccrual.count }, 1 do
      post generate_time_off_accruals_path, params: { period_start_on: Date.current.beginning_of_month.iso8601, requested_by: "payroll_admin" }
    end

    assert_redirected_to time_off_accruals_path
    generated = @employee.time_off_accruals.find_by!(time_off_policy: @sick_policy, accrual_type: "monthly_accrual", period_start_on: Date.current.beginning_of_month)
    assert_equal "pending", generated.status
    assert_equal (@sick_policy.annual_hours / 12).round(2), generated.hours
    assert_equal "payroll_admin", generated.metadata.fetch("requested_by")
  end

  test "approves PTO accrual through command action" do
    dto = TimeOff::ApproveAccrualDto.from_params(id: @time_off_accrual.id, approved_by: "payroll_admin")

    assert_equal @time_off_accrual.id, dto.accrual_id
    assert_equal "payroll_admin", dto.approved_by

    post approve_time_off_accrual_path(@time_off_accrual), params: { approved_by: "payroll_admin" }

    assert_redirected_to time_off_accruals_path
    @time_off_accrual.reload
    assert_equal "approved", @time_off_accrual.status
    assert_equal "payroll_admin", @time_off_accrual.metadata.fetch("approved_by")
    assert_equal "pto_accrual_ledger", @time_off_accrual.metadata.fetch("approved_from")
    assert_not_nil @time_off_accrual.approved_at
  end

  test "generates PTO payroll packet with lines and holdbacks" do
    dto = TimeOff::GenerateAccrualPayrollPacketDto.from_params(requested_by: "payroll_admin")

    assert_equal "payroll_admin", dto.requested_by

    post generate_time_off_accrual_payroll_packet_path, params: { requested_by: "payroll_admin" }

    assert_redirected_to time_off_accruals_path
    packet = @employer.reload.settings.fetch("pto_payroll_packet")
    assert_match(/\Apto_payroll_#{@employer.id}_#{@payroll_run.id}_/, packet.fetch("packet_id"))
    assert_equal "payroll_admin", packet.fetch("requested_by")
    assert_equal 2, packet.fetch("totals").fetch("line_count")
    assert_equal 2, packet.fetch("totals").fetch("holdback_count")
    assert_equal @approved_time_off_accrual.hours, packet.fetch("totals").fetch("accrual_hours").to_d
    assert_equal @approved_time_off_request.hours, packet.fetch("totals").fetch("usage_hours").to_d
    assert packet.fetch("lines").any? { |line| line.fetch("line_type") == "accrual_credit" && line.fetch("employee_id") == @employee.id }
    assert packet.fetch("lines").any? { |line| line.fetch("line_type") == "pto_usage" && line.fetch("employee_id") == @employee.id }
    assert packet.fetch("holdbacks").any? { |holdback| holdback.fetch("reason_code") == "pending_accrual" }

    detail = TimeOff::AccrualLedgerQuery.new.call
    assert_instance_of TimeOff::AccrualPacketDto, detail.packet
    assert_instance_of TimeOff::AccrualPacketLineDto, detail.packet_lines.first
    assert_instance_of TimeOff::AccrualIssueDto, detail.packet_holdbacks.first
  end

  test "scheduling center exposes shifts swaps and forecast DTOs" do
    detail = Scheduling::CenterQuery.new.call

    assert_instance_of Scheduling::CenterDto, detail
    assert_instance_of Scheduling::MetricDto, detail.metrics.first
    assert_instance_of Scheduling::ShiftDto, detail.shifts.first
    assert_instance_of Scheduling::SwapRequestDto, detail.swap_requests.first
    assert_instance_of Scheduling::IssueDto, detail.issues.first
    assert detail.publishable_shifts.any? { |shift| shift.id == @draft_shift.id }
    assert detail.open_shifts.any? { |shift| shift.id == @open_shift.id }
    assert detail.reviewable_swaps.any? { |swap| swap.id == @shift_swap_request.id }

    get scheduling_path

    assert_response :success
    assert_select "h1", "Workforce scheduling center"
    assert_select "h2", "Scheduling issues"
    assert_select "h2", "Swap queue"
    assert_select "h2", "Shift roster"
    assert_select "h2", "Payroll forecast ledger"
  end

  test "publishes draft shifts through command action" do
    post publish_schedule_path, params: { published_by: "schedule_admin" }

    assert_redirected_to scheduling_path
    @draft_shift.reload
    assert_equal "published", @draft_shift.status
    assert_equal "schedule_admin", @draft_shift.metadata.fetch("published_by")
    assert_not_nil @draft_shift.published_at
  end

  test "approves shift swap through command action" do
    post approve_shift_swap_path(@shift_swap_request), params: { reviewed_by: "manager_admin" }

    assert_redirected_to scheduling_path
    @shift_swap_request.reload
    assert_equal "approved", @shift_swap_request.status
    assert_equal "manager_admin", @shift_swap_request.reviewed_by
    assert_equal "manager_admin", @shift_swap_request.metadata.fetch("approved_by")
    assert_not_nil @shift_swap_request.reviewed_at
  end

  test "generates schedule payroll forecast through command action" do
    post generate_schedule_forecast_path, params: { requested_by: "payroll_admin" }

    assert_redirected_to scheduling_path
    forecast = @employer.reload.settings.fetch("schedule_payroll_forecast")
    assert_match(/\Aschedule_forecast_#{@employer.id}_#{@payroll_run.id}_/, forecast.fetch("batch_id"))
    assert_equal "payroll_admin", forecast.fetch("requested_by")
    assert_equal 1, forecast.fetch("totals").fetch("line_count")
    assert_equal 1, forecast.fetch("totals").fetch("employee_count")
    assert_equal 3, forecast.fetch("totals").fetch("holdback_count")
    assert_equal @published_shift.labor_cost_cents, forecast.fetch("totals").fetch("total_labor_cents")

    detail = Scheduling::CenterQuery.new.call
    assert_instance_of Scheduling::ForecastDto, detail.latest_forecast
    assert_instance_of Scheduling::ForecastLineDto, detail.forecast_lines.first
    assert_instance_of Scheduling::ForecastHoldbackDto, detail.forecast_holdbacks.first
  end

  test "timesheets workspace exposes approval and export DTOs" do
    detail = TimeTracking::CenterQuery.new.call

    assert_instance_of TimeTracking::CenterDto, detail
    assert_instance_of TimeTracking::MetricDto, detail.metrics.first
    assert_instance_of TimeTracking::EntryDto, detail.entries.first
    assert_instance_of TimeTracking::EmployeeSummaryDto, detail.employees.first
    assert_instance_of TimeTracking::DepartmentSummaryDto, detail.departments.first
    assert_instance_of TimeTracking::ExceptionDto, detail.exceptions.first
    assert detail.pending_entries.any? { |entry| entry.id == @submitted_time_entry.id }

    get timesheets_path

    assert_response :success
    assert_select "h1", "Timesheets"
    assert_select "h2", "Time entry review"
    assert_select "h2", "Timesheet exceptions"
    assert_select "h2", "Employee time summary"
    assert_select "h2", "Department coverage"
  end

  test "approves a submitted time entry through command action" do
    post approve_time_entry_path(@submitted_time_entry), params: { reviewed_by: "ops_console" }

    assert_redirected_to timesheets_path
    @submitted_time_entry.reload
    assert_equal "approved", @submitted_time_entry.status
    assert_equal "ops_console", @submitted_time_entry.metadata.fetch("reviewed_by")
    assert_equal "approved", @submitted_time_entry.metadata.fetch("review_decision")
    assert_not_nil @submitted_time_entry.reviewed_at
    assert_not_nil @submitted_time_entry.approved_at
  end

  test "generates a timesheet payroll export through command action" do
    post generate_time_tracking_export_path

    assert_redirected_to timesheets_path
    export = @employer.reload.settings.fetch("time_tracking_export")
    assert_match(/\Atime_export_#{@employer.id}_/, export.fetch("export_id"))
    assert_equal "ops_console", export.fetch("requested_by")
    assert_equal @payroll_run.id, export.fetch("payroll_run_id")
    assert_equal 1, export.fetch("totals").fetch("line_count")
    assert_equal 1, export.fetch("totals").fetch("holdback_count")
    assert export.fetch("totals").fetch("approved_minutes").positive?
    assert export.fetch("totals").fetch("total_gross_cents").positive?
  end

  test "expenses center exposes employee reimbursement DTOs" do
    detail = Expenses::CenterQuery.new.call

    assert_instance_of Expenses::CenterDto, detail
    assert_instance_of Expenses::MetricDto, detail.metrics.first
    assert_instance_of Expenses::ExpenseDto, detail.expenses.first
    assert_instance_of Expenses::PolicyItemDto, detail.policy_items.first
    assert detail.reviewable_expenses.any? { |expense| expense.id == @expense.id }
    assert detail.approved_expenses.any? { |expense| expense.id == @approved_expense.id }

    get expenses_path

    assert_response :success
    assert_select "h1", "Expenses and reimbursements"
    assert_select "h2", "Expense review queue"
    assert_select "h2", "Policy exceptions"
    assert_select "h2", "Expense ledger"
    assert_select "h2", "Reimbursement batch ledger"
  end

  test "approves a receipt-ready employee expense through command action" do
    post approve_expense_path(@expense), params: { reviewed_by: "ops_console" }

    assert_redirected_to expenses_path
    @expense.reload
    assert_equal "approved", @expense.status
    assert_equal "ops_console", @expense.metadata.fetch("reviewed_by")
    assert_not_nil @expense.approved_at
  end

  test "generates an expense reimbursement batch through command action" do
    post generate_expense_reimbursement_batch_path

    assert_redirected_to expenses_path
    batch = @employer.reload.settings.fetch("expense_reimbursement_batch")
    assert_match(/\Aexpense_reimbursements_#{@employer.id}_/, batch.fetch("batch_id"))
    assert_equal "ops_console", batch.fetch("requested_by")
    assert_equal 1, batch.fetch("totals").fetch("reimbursement_count")
    assert_equal 1, batch.fetch("totals").fetch("employee_count")
    assert_equal 2, batch.fetch("totals").fetch("holdback_count")
    assert_equal @approved_expense.amount_cents, batch.fetch("totals").fetch("total_cents")
    assert_equal "reimbursed", @approved_expense.reload.status

    detail = Expenses::CenterQuery.new.call
    assert_instance_of Expenses::BatchDto, detail.latest_batch
    assert_instance_of Expenses::BatchLineDto, detail.batch_lines.first
    assert_instance_of Expenses::BatchHoldbackDto, detail.batch_holdbacks.first
  end

  test "payroll deductions center exposes recurring order DTOs" do
    detail = Deductions::CenterQuery.new.call

    assert_instance_of Deductions::CenterDto, detail
    assert_instance_of Deductions::MetricDto, detail.metrics.first
    assert_instance_of Deductions::PayrollRunDto, detail.payroll_run
    assert_instance_of Deductions::DeductionDto, detail.deductions.first
    assert_instance_of Deductions::IssueDto, detail.issues.first
    assert detail.active_deductions.any? { |deduction| deduction.id == @active_employee_deduction.id }
    assert detail.approvable_deductions.any? { |deduction| deduction.id == @pending_employee_deduction.id }

    get payroll_deductions_center_path

    assert_response :success
    assert_select "h1", "Payroll deductions and garnishments"
    assert_select "h2", "Deduction issues"
    assert_select "h2", "Order mix"
    assert_select "h2", "Deduction roster"
    assert_select "h2", "Deduction packet ledger"
  end

  test "approves a pending employee deduction through command action" do
    post approve_employee_deduction_path(@pending_employee_deduction), params: { approved_by: "payroll_admin" }

    assert_redirected_to payroll_deductions_center_path
    @pending_employee_deduction.reload
    assert_equal "active", @pending_employee_deduction.status
    assert_equal "payroll_admin", @pending_employee_deduction.metadata.fetch("approved_by")
    assert_not_nil @pending_employee_deduction.approved_at
  end

  test "pauses an active employee deduction through command action" do
    post pause_employee_deduction_path(@pausable_employee_deduction), params: { paused_by: "payroll_admin", reason: "Employee requested plan change" }

    assert_redirected_to payroll_deductions_center_path
    @pausable_employee_deduction.reload
    assert_equal "paused", @pausable_employee_deduction.status
    assert_equal "payroll_admin", @pausable_employee_deduction.metadata.fetch("paused_by")
    assert_equal "Employee requested plan change", @pausable_employee_deduction.metadata.fetch("paused_reason")
    assert_not_nil @pausable_employee_deduction.paused_at
  end

  test "generates employee deduction payroll packet through command action" do
    post generate_employee_deductions_packet_path, params: { requested_by: "payroll_admin" }

    assert_redirected_to payroll_deductions_center_path
    batch = @employer.reload.settings.fetch("employee_deductions_packet")
    assert_match(/\Aemployee_deductions_#{@employer.id}_#{@payroll_run.id}_/, batch.fetch("batch_id"))
    assert_equal "payroll_admin", batch.fetch("requested_by")
    assert_equal 2, batch.fetch("totals").fetch("line_count")
    assert_equal 1, batch.fetch("totals").fetch("employee_count")
    assert_equal 2, batch.fetch("totals").fetch("holdback_count")
    assert batch.fetch("totals").fetch("total_cents").positive?
    assert @payroll_run.payroll_deductions.exists?(code: "EMPLOYEE_DEDUCTION_#{@active_employee_deduction.id}")

    detail = Deductions::CenterQuery.new.call
    assert_instance_of Deductions::PacketDto, detail.latest_packet
    assert_instance_of Deductions::PacketLineDto, detail.packet_lines.first
    assert_instance_of Deductions::PacketHoldbackDto, detail.packet_holdbacks.first
  end

  test "garnishment compliance center exposes legal order DTOs" do
    detail = Garnishments::CenterQuery.new.call

    assert_instance_of Garnishments::CenterDto, detail
    assert_instance_of Garnishments::MetricDto, detail.metrics.first
    assert_instance_of Garnishments::OrderDto, detail.orders.first
    assert_instance_of Garnishments::IssueDto, detail.issues.first
    assert detail.orders.any? { |order| order.id == @active_employee_deduction.id }
    assert detail.orders.any? { |order| order.id == @blocked_garnishment_order.id }

    get payroll_garnishments_path

    assert_response :success
    assert_select "h1", "Garnishment compliance"
    assert_select "h2", "Legal order blockers"
    assert_select "h2", "Disposable earnings review"
    assert_select "h2", "Garnishment order roster"
    assert_select "h2", "Remittance packet lines"
    assert_select "h2", "Agency remittance summary"
    assert_select "h2", "Packet holdbacks"
  end

  test "approves a blocked garnishment order through command action" do
    post approve_garnishment_order_path(@blocked_garnishment_order), params: { approved_by: "payroll_admin" }

    assert_redirected_to payroll_garnishments_path
    @blocked_garnishment_order.reload
    assert_equal "active", @blocked_garnishment_order.status
    assert_equal "payroll_admin", @blocked_garnishment_order.metadata.fetch("approved_by")
    assert_not_nil @blocked_garnishment_order.approved_at
  end

  test "pauses an active garnishment order through command action" do
    post pause_garnishment_order_path(@active_employee_deduction), params: { paused_by: "payroll_admin", reason: "Release order received" }

    assert_redirected_to payroll_garnishments_path
    @active_employee_deduction.reload
    assert_equal "paused", @active_employee_deduction.status
    assert_equal "payroll_admin", @active_employee_deduction.metadata.fetch("paused_by")
    assert_equal "Release order received", @active_employee_deduction.metadata.fetch("paused_reason")
    assert_not_nil @active_employee_deduction.paused_at
  end

  test "generates garnishment remittance packet through command action" do
    post generate_garnishment_remittance_packet_path, params: { requested_by: "payroll_admin" }

    assert_redirected_to payroll_garnishments_path
    packet = @employer.reload.settings.fetch("garnishment_remittance_packet")
    assert_match(/\Agarnishments_#{@employer.id}_#{@payroll_run.id}_/, packet.fetch("packet_id"))
    assert_equal "payroll_admin", packet.fetch("requested_by")
    assert_equal 2, packet.fetch("totals").fetch("order_count")
    assert_equal 1, packet.fetch("totals").fetch("remittance_count")
    assert_equal 1, packet.fetch("totals").fetch("agency_count")
    assert_equal 1, packet.fetch("totals").fetch("holdback_count")
    assert_equal @active_employee_deduction.amount_cents, packet.fetch("totals").fetch("total_withheld_cents")
    assert @payroll_run.payroll_deductions.exists?(code: "EMPLOYEE_DEDUCTION_#{@active_employee_deduction.id}")

    detail = Garnishments::CenterQuery.new.call
    assert_instance_of Garnishments::PacketDto, detail.latest_packet
    assert_instance_of Garnishments::PacketLineDto, detail.packet_lines.first
    assert_instance_of Garnishments::AgencySummaryDto, detail.agency_summaries.first
    assert_instance_of Garnishments::IssueDto, detail.packet_holdbacks.first
  end

  test "payroll calendar center exposes approval control DTOs" do
    detail = PayrollCalendar::CenterQuery.new.call

    assert_instance_of PayrollCalendar::CenterDto, detail
    assert_instance_of PayrollCalendar::MetricDto, detail.metrics.first
    assert_instance_of PayrollCalendar::ScheduleDto, detail.schedule
    assert_instance_of PayrollCalendar::RunDto, detail.payroll_run
    assert_instance_of PayrollCalendar::ApprovalStepDto, detail.approval_steps.first
    assert_instance_of PayrollCalendar::CalendarEventDto, detail.calendar_events.first
    assert_instance_of PayrollCalendar::RiskDto, detail.risks.first
    assert detail.incomplete_steps.any? { |step| step.id == @payroll_approval_step.id }

    get payroll_calendar_path

    assert_response :success
    assert_select "h1", "Payroll calendar control center"
    assert_select "h2", "Pay cycle control tower"
    assert_select "h2", "Cutoff calendar"
    assert_select "h2", "Approval checklist"
    assert_select "h2", "Payroll risks"
    assert_select "h2", "Checklist ledger"
  end

  test "generates payroll calendar approval checklist through command action" do
    post generate_payroll_calendar_checklist_path

    assert_redirected_to payroll_calendar_path
    batch = @employer.reload.settings.fetch("payroll_calendar_checklist")
    assert_match(/\Apayroll_calendar_#{@employer.id}_#{@payroll_run.id}_/, batch.fetch("batch_id"))
    assert_equal "ops_console", batch.fetch("requested_by")
    assert_equal 7, batch.fetch("totals").fetch("step_count")
    assert_operator batch.fetch("totals").fetch("blocked_count"), :>, 0
    assert_equal 7, @payroll_run.payroll_approval_steps.count

    follow_redirect!

    assert_response :success
    assert_includes response.body, batch.fetch("batch_id")
    assert_select "p", "Blocked"

    detail = PayrollCalendar::CenterQuery.new.call
    assert_instance_of PayrollCalendar::ChecklistDto, detail.latest_checklist
    assert_instance_of PayrollCalendar::ChecklistLineDto, detail.checklist_lines.first
  end

  test "completes a payroll approval step through command action" do
    post complete_payroll_approval_step_path(@payroll_approval_step), params: { completed_by: "ops_console" }

    assert_redirected_to payroll_calendar_path
    @payroll_approval_step.reload
    assert_equal "completed", @payroll_approval_step.status
    assert_equal "ops_console", @payroll_approval_step.completed_by
    assert_equal "ops_console", @payroll_approval_step.metadata.fetch("completed_by")
    assert_not_nil @payroll_approval_step.completed_at
  end

  test "payroll funding center exposes direct deposit DTOs" do
    detail = PayrollFunding::CenterQuery.new.call

    assert_instance_of PayrollFunding::CenterDto, detail
    assert_instance_of PayrollFunding::MetricDto, detail.metrics.first
    assert_instance_of PayrollFunding::EmployerAccountDto, detail.employer_accounts.first
    assert_instance_of PayrollFunding::EmployeeAccountDto, detail.employee_accounts.first
    assert_instance_of PayrollFunding::RunFundingDto, detail.payroll_run
    assert_instance_of PayrollFunding::FundingIssueDto, detail.funding_issues.first
    assert detail.pending_accounts.any? { |account| account.id == @employee_bank_account.id }

    get payroll_funding_path

    assert_response :success
    assert_select "h1", "Payroll funding and direct deposit"
    assert_select "h2", "Bank readiness"
    assert_select "h2", "Payroll funding issues"
    assert_select "h2", "Direct deposit review"
    assert_select "h2", "ACH batch ledger"
  end

  test "verifies an employee bank account through command action" do
    post verify_employee_bank_account_path(@employee_bank_account), params: { reviewed_by: "ops_console" }

    assert_redirected_to payroll_funding_path
    @employee_bank_account.reload
    assert_equal "verified", @employee_bank_account.status
    assert_equal "ops_console", @employee_bank_account.metadata.fetch("verified_by")
    assert_not_nil @employee_bank_account.verified_at
  end

  test "generates payroll funding ACH batches with holdbacks and credits" do
    post generate_payroll_funding_batch_path

    assert_redirected_to payroll_funding_path
    holdback_batch = @employer.reload.settings.fetch("payroll_funding_batch")
    assert_match(/\Apayroll_ach_#{@employer.id}_#{@payroll_run.id}_/, holdback_batch.fetch("batch_id"))
    assert_equal "ops_console", holdback_batch.fetch("requested_by")
    assert_equal 0, holdback_batch.fetch("totals").fetch("credit_count")
    assert_equal 1, holdback_batch.fetch("totals").fetch("holdback_count")
    assert_equal "Employee direct deposit account is not verified", holdback_batch.fetch("holdbacks").first.fetch("reason")

    detail = PayrollFunding::CenterQuery.new.call
    assert_instance_of PayrollFunding::BatchDto, detail.latest_batch
    assert_instance_of PayrollFunding::BatchHoldbackDto, detail.batch_holdbacks.first

    @employee_bank_account.verify!(reviewed_by: "ops_console")

    post generate_payroll_funding_batch_path

    credit_batch = @employer.reload.settings.fetch("payroll_funding_batch")
    assert_equal 1, credit_batch.fetch("totals").fetch("credit_count")
    assert_equal 1, credit_batch.fetch("totals").fetch("employee_count")
    assert_equal 0, credit_batch.fetch("totals").fetch("holdback_count")
    assert credit_batch.fetch("totals").fetch("total_cents").positive?
    assert_equal @employee.full_name, credit_batch.fetch("credits").first.fetch("employee_name")

    detail = PayrollFunding::CenterQuery.new.call
    assert_instance_of PayrollFunding::BatchCreditDto, detail.batch_credits.first
  end

  test "pay statements center exposes employee document DTOs" do
    detail = PayStatements::CenterQuery.new.call

    assert_instance_of PayStatements::CenterDto, detail
    assert_instance_of PayStatements::MetricDto, detail.metrics.first
    assert_instance_of PayStatements::StatementDto, detail.statements.first
    assert_instance_of PayStatements::PayrollRunDto, detail.payroll_run
    assert_instance_of PayStatements::DeliveryIssueDto, detail.delivery_issues.first
    assert detail.deliverable_statements.any? { |statement| statement.id == @pay_statement.id }

    get pay_statements_path

    assert_response :success
    assert_select "h1", "Pay statements and employee documents"
    assert_select "h2", "Delivery queue"
    assert_select "h2", "Statement delivery issues"
    assert_select "h2", "Statement ledger"
    assert_select "h2", "Statement batch ledger"
  end

  test "delivers a generated pay statement through command action" do
    post deliver_pay_statement_path(@pay_statement), params: { delivered_by: "ops_console" }

    assert_redirected_to pay_statements_path
    @pay_statement.reload
    assert_equal "delivered", @pay_statement.status
    assert_equal "ops_console", @pay_statement.metadata.fetch("delivered_by")
    assert_not_nil @pay_statement.delivered_at
  end

  test "generates a pay statement batch through command action" do
    post generate_pay_statement_batch_path

    assert_redirected_to pay_statements_path
    batch = @employer.reload.settings.fetch("pay_statement_batch")
    assert_match(/\Apay_statements_#{@employer.id}_#{@payroll_run.id}_/, batch.fetch("batch_id"))
    assert_equal "ops_console", batch.fetch("requested_by")
    assert_equal 1, batch.fetch("totals").fetch("statement_count")
    assert_equal 1, batch.fetch("totals").fetch("employee_count")
    assert_equal 0, batch.fetch("totals").fetch("holdback_count")
    assert_equal @employee.full_name, batch.fetch("statements").first.fetch("employee_name")

    detail = PayStatements::CenterQuery.new.call
    assert_instance_of PayStatements::BatchDto, detail.latest_batch
    assert_instance_of PayStatements::BatchLineDto, detail.batch_lines.first
  end

  test "year-end tax forms center exposes W-2 and 1099 DTOs" do
    detail = YearEnd::TaxFormsQuery.new.call

    assert_instance_of YearEnd::CenterDto, detail
    assert_instance_of YearEnd::MetricDto, detail.metrics.first
    assert_instance_of YearEnd::TaxFormDto, detail.forms.first
    assert_instance_of YearEnd::IssueDto, detail.issues.first
    assert detail.forms.any? { |form| form.id == @year_end_tax_form.id }
    assert detail.forms.any? { |form| form.id == @contractor_year_end_tax_form.id }

    get year_end_tax_forms_path

    assert_response :success
    assert_select "h1", "Year-end tax forms"
    assert_select "h2", "Tax form delivery queue"
    assert_select "h2", "Filing holdbacks"
    assert_select "h2", "Year-end form ledger"
    assert_select "h2", "Packet form lines"
    assert_select "h2", "Packet holdbacks"
  end

  test "delivers a year-end tax form through command action" do
    post deliver_year_end_tax_form_path(@year_end_tax_form), params: { delivered_by: "tax_ops", tax_year: Date.current.year }

    assert_redirected_to year_end_tax_forms_path(tax_year: Date.current.year)
    @year_end_tax_form.reload
    assert_equal "delivered", @year_end_tax_form.status
    assert_equal "tax_ops", @year_end_tax_form.metadata.fetch("delivered_by")
    assert_not_nil @year_end_tax_form.delivered_at
  end

  test "generates a year-end tax form packet through command action" do
    post generate_year_end_tax_form_packet_path, params: { requested_by: "tax_ops", tax_year: Date.current.year }

    assert_redirected_to year_end_tax_forms_path(tax_year: Date.current.year)
    packet = @employer.reload.settings.fetch("year_end_tax_form_packet")
    assert_match(/\Ayear_end_tax_forms_#{@employer.id}_#{Date.current.year}_/, packet.fetch("packet_id"))
    assert_equal "tax_ops", packet.fetch("requested_by")
    assert_equal Date.current.year, packet.fetch("tax_year")
    assert_equal 2, packet.fetch("totals").fetch("form_count")
    assert_equal 1, packet.fetch("totals").fetch("w2_count")
    assert_equal 1, packet.fetch("totals").fetch("form_1099_count")
    assert packet.fetch("totals").fetch("gross_wages_cents").positive?
    assert_equal @approved_contractor_tax_payment.amount_cents, packet.fetch("totals").fetch("contractor_payment_cents")

    detail = YearEnd::TaxFormsQuery.new.call
    assert_instance_of YearEnd::PacketDto, detail.packet
    assert_instance_of YearEnd::PacketLineDto, detail.packet_lines.first
  end

  test "benefit plan administration exposes plan catalog DTOs" do
    detail = Benefits::PlanAdministrationQuery.new.call

    assert_instance_of Benefits::PlanAdministrationCenterDto, detail
    assert_instance_of Benefits::PlanAdminMetricDto, detail.metrics.first
    assert_instance_of Benefits::PlanDesignDto, detail.plans.first
    assert_instance_of Benefits::PlanReadinessIssueDto, detail.issues.first
    assert_instance_of Benefits::VitablePlanCatalogSnapshotDto, detail.remote_snapshot
    assert detail.plans.any? { |plan| plan.id == @plan.id }
    assert detail.issues.any? { |issue| issue.plan_id == @plan.id }

    get benefits_plan_admin_path

    assert_response :success
    assert_select "h1", "Benefit plan administration"
    assert_select "h2", "Remote plan mappings"
    assert_select "h2", "Plan design catalog"
    assert_select "h2", "Readiness issues"
    assert_select "h2", "Catalog packet lines"
    assert_select "h2", "Packet holdbacks"
    assert_select "button", "Refresh plan mappings"
  end

  test "refreshes Vitable plan mappings as missing credentials sync run without API key" do
    assert_difference -> { @connection.sync_runs.where(operation: "plan_mapping_refresh").count }, 1 do
      post refresh_vitable_plan_mappings_path, params: { requested_by: "benefits_admin" }
    end

    assert_redirected_to benefits_plan_admin_path
    sync = @connection.sync_runs.where(operation: "plan_mapping_refresh").recent_first.first
    assert_equal "needs_credentials", sync.status
    assert_match @connection.api_key_reference, sync.error_message
    assert_equal "benefits_admin", sync.stats.fetch("requested_by")
    assert_equal "/v1/plans", sync.stats.fetch("endpoint")
  end

  test "successful Vitable plan mapping refresh stores remote plan ids" do
    response_class = Data.define(:data)
    gateway_class = Class.new do
      define_method(:initialize) { |_connection| }
      define_method(:list_all_plans) do
        response_class.new(
          data: [
            { id: "plan_remote_primary", name: "Primary Care" },
            { id: "plan_remote_dental", name: "Dental" },
            { id: "plan_remote_unknown", name: "Hospital Indemnity" }
          ]
        )
      end
    end
    previous_key = ENV[@connection.api_key_reference]
    ENV[@connection.api_key_reference] = "vit_apk_test_value"

    result = Benefits::RefreshVitablePlanMappingsCommand.new(
      dto: Benefits::RefreshVitablePlanMappingsDto.new(requested_by: "benefits_admin"),
      gateway_class:
    ).call

    assert result.success?
    assert_equal "plan_remote_primary", @plan.reload.vitable_id
    assert_equal "plan_remote_dental", @pending_plan.reload.vitable_id
    snapshot = @employer.reload.settings.fetch("vitable_plan_catalog_snapshot")
    assert_equal 3, snapshot.fetch("remote_plans").count
    assert_equal 2, snapshot.fetch("mapped_plan_count")
    assert_equal "plan_remote_unknown", snapshot.fetch("unmatched_remote_plans").first.fetch("id")
    assert_equal "plans.list", @plan.metadata.dig("vitable_plan_mapping", "matched_by")

    detail = Benefits::PlanAdministrationQuery.new.call
    assert_instance_of Benefits::VitablePlanMappingDto, detail.mapped_plans.first
    assert_instance_of Benefits::VitablePlanMappingIssueDto, detail.mapping_issues.first
  ensure
    ENV[@connection.api_key_reference] = previous_key
  end

  test "Vitable plan mapping refresh fails when remote plan omits id" do
    response_class = Data.define(:data)
    gateway_class = Class.new do
      define_method(:initialize) { |_connection| }
      define_method(:list_all_plans) do
        response_class.new(
          data: [
            { name: "Primary Care" }
          ]
        )
      end
    end
    previous_key = ENV[@connection.api_key_reference]
    ENV[@connection.api_key_reference] = "vit_apk_test_value"

    result = Benefits::RefreshVitablePlanMappingsCommand.new(
      dto: Benefits::RefreshVitablePlanMappingsDto.new(requested_by: "benefits_admin"),
      gateway_class:
    ).call

    assert result.failure?
    assert_nil @plan.reload.vitable_id
    assert_nil @employer.reload.settings.to_h.fetch("vitable_plan_catalog_snapshot", nil)
    sync = @connection.sync_runs.where(operation: "plan_mapping_refresh").recent_first.first
    assert_equal "failed", sync.status
    assert_match "remote plan ID", sync.error_message
    assert_match "remote plan ID", result.errors.to_sentence
  ensure
    ENV[@connection.api_key_reference] = previous_key
  end

  test "Vitable plan mapping refresh fails when remote plan omits name" do
    response_class = Data.define(:data)
    gateway_class = Class.new do
      define_method(:initialize) { |_connection| }
      define_method(:list_all_plans) do
        response_class.new(
          data: [
            { id: "plan_remote_primary" }
          ]
        )
      end
    end
    previous_key = ENV[@connection.api_key_reference]
    ENV[@connection.api_key_reference] = "vit_apk_test_value"

    result = Benefits::RefreshVitablePlanMappingsCommand.new(
      dto: Benefits::RefreshVitablePlanMappingsDto.new(requested_by: "benefits_admin"),
      gateway_class:
    ).call

    assert result.failure?
    assert_nil @plan.reload.vitable_id
    assert_nil @employer.reload.settings.to_h.fetch("vitable_plan_catalog_snapshot", nil)
    sync = @connection.sync_runs.where(operation: "plan_mapping_refresh").recent_first.first
    assert_equal "failed", sync.status
    assert_match "remote plan name", sync.error_message
    assert_match "remote plan name", result.errors.to_sentence
  ensure
    ENV[@connection.api_key_reference] = previous_key
  end

  test "Vitable plan mapping refresh keeps one remote plan per local plan" do
    response_class = Data.define(:data)
    gateway_class = Class.new do
      define_method(:initialize) { |_connection| }
      define_method(:list_all_plans) do
        response_class.new(
          data: [
            { id: "plan_remote_primary", name: "Primary Care" },
            { id: "plan_remote_primary_duplicate", name: "Primary Care" }
          ]
        )
      end
    end
    previous_key = ENV[@connection.api_key_reference]
    ENV[@connection.api_key_reference] = "vit_apk_test_value"

    result = Benefits::RefreshVitablePlanMappingsCommand.new(
      dto: Benefits::RefreshVitablePlanMappingsDto.new(requested_by: "benefits_admin"),
      gateway_class:
    ).call

    assert result.success?
    assert_equal "plan_remote_primary", @plan.reload.vitable_id
    snapshot = @employer.reload.settings.fetch("vitable_plan_catalog_snapshot")
    duplicate = snapshot.fetch("unmatched_remote_plans").find { |plan| plan.fetch("id") == "plan_remote_primary_duplicate" }

    assert_equal 1, snapshot.fetch("mapped_plan_count")
    assert_equal "local_plan_already_mapped", duplicate.fetch("reason")
    assert_equal [ @plan.id ], duplicate.fetch("matched_local_plan_ids")
    assert_equal [ @plan.name ], duplicate.fetch("matched_local_plan_names")

    detail = Benefits::PlanAdministrationQuery.new.call
    duplicate_issue = detail.mapping_issues.find { |issue| issue.remote_plan_id == "plan_remote_primary_duplicate" }
    assert_equal "local_plan_already_mapped", duplicate_issue.reason
    assert_equal [ @plan.name ], duplicate_issue.candidate_plan_names
  ensure
    ENV[@connection.api_key_reference] = previous_key
  end

  test "publishes a ready benefit plan through command action" do
    prepare_publishable_plan(@plan)
    dto = Benefits::PublishPlanDto.from_params(id: @plan.id, published_by: "benefits_admin")

    assert_equal @plan.id, dto.plan_id
    assert_equal "benefits_admin", dto.published_by

    post publish_benefit_plan_path(@plan), params: { published_by: "benefits_admin" }

    assert_redirected_to benefits_plan_admin_path
    @plan.reload
    assert_equal "published", @plan.review_status
    assert_equal "available", @plan.status
    assert_equal "benefits_admin", @plan.metadata.fetch("published_by")
    assert_equal "benefit_plan_administration", @plan.metadata.fetch("published_from")
    assert_not_nil @plan.published_at
  end

  test "generates benefit plan catalog packet with lines and holdbacks" do
    prepare_publishable_plan(@plan, review_status: "published")
    prepare_publishable_plan(@pending_plan, employee_contribution_cents: 2_000, employer_contribution_cents: 2_500)

    dto = Benefits::GeneratePlanCatalogPacketDto.from_params(requested_by: "benefits_admin")

    assert_equal "benefits_admin", dto.requested_by

    post generate_benefit_plan_catalog_packet_path, params: { requested_by: "benefits_admin" }

    assert_redirected_to benefits_plan_admin_path
    packet = @employer.reload.settings.fetch("benefit_plan_catalog_packet")
    assert_match(/\Abenefit_plan_catalog_#{@employer.id}_/, packet.fetch("packet_id"))
    assert_equal "benefits_admin", packet.fetch("requested_by")
    assert_equal 3, packet.fetch("totals").fetch("plan_count")
    assert_equal 1, packet.fetch("totals").fetch("ready_count")
    assert_equal 2, packet.fetch("totals").fetch("holdback_count")
    assert_equal @plan.id, packet.fetch("plans").first.fetch("plan_id")
    assert packet.fetch("holdbacks").any? { |holdback| holdback.fetch("plan_id") == @pending_plan.id && holdback.fetch("reason_code") == "unpublished_plan" }

    detail = Benefits::PlanAdministrationQuery.new.call

    assert_instance_of Benefits::PlanCatalogPacketDto, detail.packet
    assert_instance_of Benefits::PlanCatalogLineDto, detail.packet_lines.first
    assert_instance_of Benefits::PlanReadinessIssueDto, detail.packet_holdbacks.first
  end

  test "open enrollment center exposes campaign DTOs" do
    detail = OpenEnrollment::CenterQuery.new.call

    assert_instance_of OpenEnrollment::CenterDto, detail
    assert_instance_of OpenEnrollment::MetricDto, detail.metrics.first
    assert_instance_of OpenEnrollment::CampaignDto, detail.campaign
    assert_instance_of OpenEnrollment::InvitationDto, detail.invitations.first
    assert_instance_of OpenEnrollment::PlanReadinessDto, detail.plans.first
    assert_instance_of OpenEnrollment::IssueDto, detail.issues.first
    assert detail.pending_invitations.any? { |invitation| invitation.id == @open_enrollment_invitation.id }

    get benefits_open_enrollment_path

    assert_response :success
    assert_select "h1", "Open enrollment"
    assert_select "h2", "Enrollment blockers"
    assert_select "h2", "Plan readiness"
    assert_select "h2", "Employee election queue"
    assert_select "h2", "Open enrollment batch ledger"
  end

  test "launches open enrollment invitations through command action" do
    post launch_open_enrollment_path

    assert_redirected_to benefits_open_enrollment_path
    @open_enrollment_campaign.reload
    @open_enrollment_invitation.reload
    assert_equal "active", @open_enrollment_campaign.status
    assert_equal "sent", @open_enrollment_invitation.status
    assert_equal "ops_console", @open_enrollment_invitation.metadata.fetch("sent_by")
    batch = @open_enrollment_campaign.metadata.fetch("open_enrollment_batch")
    assert_match(/\Aopen_enrollment_launch_#{@employer.id}_/, batch.fetch("batch_id"))
    assert_equal 1, batch.fetch("totals").fetch("sent_count")

    follow_redirect!

    assert_response :success
    assert_includes response.body, batch.fetch("batch_id")
    assert_select "p", "Sent"

    detail = OpenEnrollment::CenterQuery.new.call
    assert_instance_of OpenEnrollment::BatchDto, detail.latest_batch
    assert_instance_of OpenEnrollment::BatchLineDto, detail.batch_lines.first
  end

  test "sends open enrollment reminders through command action" do
    @open_enrollment_invitation.update!(status: "sent", sent_at: 1.day.ago)

    post send_open_enrollment_reminders_path

    assert_redirected_to benefits_open_enrollment_path
    @open_enrollment_campaign.reload
    @open_enrollment_invitation.reload
    assert_equal "reminded", @open_enrollment_invitation.status
    assert_equal "ops_console", @open_enrollment_invitation.metadata.fetch("last_reminded_by")
    assert_not_nil @open_enrollment_invitation.last_reminded_at
    batch = @open_enrollment_campaign.metadata.fetch("open_enrollment_batch")
    assert_match(/\Aopen_enrollment_reminder_#{@employer.id}_/, batch.fetch("batch_id"))
    assert_equal 1, batch.fetch("totals").fetch("reminder_count")

    follow_redirect!

    assert_response :success
    assert_includes response.body, batch.fetch("batch_id")
    assert_select "p", "Reminders"

    detail = OpenEnrollment::CenterQuery.new.call
    assert_instance_of OpenEnrollment::BatchDto, detail.latest_batch
    assert_instance_of OpenEnrollment::BatchLineDto, detail.batch_lines.first
  end

  test "benefits billing center exposes invoice reconciliation DTOs" do
    detail = Benefits::BillingQuery.new.call

    assert_instance_of Benefits::BillingCenterDto, detail
    assert_instance_of Benefits::BillingMetricDto, detail.metrics.first
    assert_instance_of Benefits::BillingInvoiceDto, detail.invoices.first
    assert_instance_of Benefits::BillingLineDto, detail.lines.first
    assert_instance_of Benefits::BillingVarianceDto, detail.variances.first
    assert detail.blocked_lines.any? { |line| line.id == @benefit_invoice_variance_line.id }

    get benefits_billing_path

    assert_response :success
    assert_select "h1", "Benefits billing and carrier payments"
    assert_select "h2", "Billing exceptions"
    assert_select "h2", "Invoice ledger"
    assert_select "h2", "Invoice line reconciliation"
    assert_select "h2", "Billing packet ledger"
  end

  test "approves a benefit invoice through command action" do
    post approve_benefit_invoice_path(@benefit_invoice), params: { reviewed_by: "finance_admin" }

    assert_redirected_to benefits_billing_path
    @benefit_invoice.reload
    assert_equal "approved", @benefit_invoice.status
    assert_equal "finance_admin", @benefit_invoice.metadata.fetch("approved_by")
    assert_not_nil @benefit_invoice.approved_at
  end

  test "generates a benefit billing packet with payment lines and holdbacks" do
    post generate_benefit_billing_packet_path

    assert_redirected_to benefits_billing_path
    packet = @employer.reload.settings.fetch("benefit_billing_packet")
    assert_match(/\Abenefit_billing_#{@employer.id}_#{@benefit_invoice.id}_/, packet.fetch("packet_id"))
    assert_equal "ops_console", packet.fetch("requested_by")
    assert_equal 1, packet.fetch("totals").fetch("payment_count")
    assert_equal 1, packet.fetch("totals").fetch("holdback_count")
    assert_equal @benefit_invoice_line.amount_cents, packet.fetch("totals").fetch("total_cents")
    assert_equal @employee.full_name, packet.fetch("payments").first.fetch("employee_name")
    assert_equal "variance", packet.fetch("holdbacks").first.fetch("status")

    detail = Benefits::BillingQuery.new.call
    assert_instance_of Benefits::BillingPacketDto, detail.latest_packet
    assert_instance_of Benefits::BillingPacketLineDto, detail.packet_lines.first
    assert_instance_of Benefits::BillingPacketHoldbackDto, detail.packet_holdbacks.first
  end

  test "contractor payments center exposes contractor payment DTOs" do
    detail = Contractors::CenterQuery.new.call

    assert_instance_of Contractors::CenterDto, detail
    assert_instance_of Contractors::MetricDto, detail.metrics.first
    assert_instance_of Contractors::ContractorDto, detail.contractors.first
    assert_instance_of Contractors::PaymentDto, detail.payments.first
    assert_instance_of Contractors::ReadinessItemDto, detail.readiness_items.first
    assert detail.pending_payments.any? { |payment| payment.id == @contractor_payment.id }

    get contractors_path

    assert_response :success
    assert_select "h1", "Contractor payments center"
    assert_select "h2", "Payment approvals"
    assert_select "h2", "Readiness recommendations"
    assert_select "h2", "Contractor roster"
    assert_select "h2", "Payment batch ledger"
  end

  test "approves a contractor payment through command action" do
    post approve_contractor_payment_path(@contractor_payment), params: { reviewed_by: "ops_console" }

    assert_redirected_to contractors_path
    @contractor_payment.reload
    assert_equal "approved", @contractor_payment.status
    assert_equal "ops_console", @contractor_payment.metadata.fetch("reviewed_by")
    assert_not_nil @contractor_payment.approved_at
  end

  test "generates a contractor payment batch through command action" do
    @contractor_payment.approve!(reviewed_by: "ops_console")

    post generate_contractor_payment_batch_path

    assert_redirected_to contractors_path
    batch = @employer.reload.settings.fetch("contractor_payment_batch")
    assert_match(/\Acontractor_payments_#{@employer.id}_/, batch.fetch("batch_id"))
    assert_equal "ops_console", batch.fetch("requested_by")
    assert_equal 2, batch.fetch("totals").fetch("payment_count")
    assert_equal 1, batch.fetch("totals").fetch("contractor_count")
    assert_equal 1, batch.fetch("totals").fetch("holdback_count")
    assert_equal @contractor_payment.amount_cents + @approved_contractor_tax_payment.amount_cents, batch.fetch("totals").fetch("total_cents")

    detail = Contractors::CenterQuery.new.call
    assert_instance_of Contractors::BatchDto, detail.latest_batch
    assert_instance_of Contractors::BatchPaymentDto, detail.batch_payments.first
    assert_instance_of Contractors::BatchHoldbackDto, detail.batch_holdbacks.first
  end

  test "employee profile exposes a feature-rich employee 360 DTO" do
    profile = Employees::DetailQuery.new.call(@employee.id)

    assert_instance_of Employees::ProfileDto, profile
    assert_instance_of Employees::ProfileMetricDto, profile.metrics.first
    assert_instance_of Employees::ProfileTimelineItemDto, profile.timeline.first
    assert_instance_of Operations::EnrollmentDto, profile.enrollments.first
    assert_instance_of Operations::OnboardingTaskDto, profile.onboarding_tasks.first

    get employee_path(@employee)

    assert_response :success
    assert_select "h1", @employee.full_name
    assert_select "h2", "Benefit elections"
    assert_select "h2", "Payroll ledger"
    assert_select "h2", "PTO and compliance"
  end

  test "payroll run workspace exposes preflight and employee pay line DTOs" do
    detail = Payroll::RunDetailQuery.new.call(@payroll_run.id)

    assert_instance_of Payroll::RunDetailDto, detail
    assert_instance_of Payroll::RunPreflightCheckDto, detail.preflight_checks.first
    assert_instance_of Payroll::RunEmployeeLineDto, detail.line_items.first
    assert_equal @employee.full_name, detail.line_items.first.employee_name

    get payroll_run_path(@payroll_run)

    assert_response :success
    assert_select "h1", "#{@payroll_run.pay_date.strftime("%B %-d, %Y")} payroll"
    assert_select "h2", "Preflight checklist"
    assert_select "h2", "Employee pay lines"
    assert_select "h2", "Export payload"
  end

  test "payroll benefits export workspace exposes manifest DTOs" do
    detail = Payroll::BenefitsExportQuery.new.call(@payroll_run.id)

    assert_instance_of Payroll::BenefitsExportDetailDto, detail
    assert_instance_of Payroll::BenefitsExportMetricDto, detail.metrics.first
    assert_instance_of Payroll::BenefitsExportPreflightCheckDto, detail.preflight_checks.first
    assert_instance_of Payroll::BenefitsExportLineDto, detail.lines.first
    assert_equal 1, detail.included_lines.count
    assert_equal 2, detail.holdback_lines.count

    get payroll_run_benefits_export_path(@payroll_run)

    assert_response :success
    assert_select "h1", "Benefits deduction export"
    assert_select "h2", "Export preflight"
    assert_select "h2", "Manifest payload"
    assert_select "h2", "Included deduction lines"
    assert_select "h2", "Holdbacks"
  end

  test "generates a payroll benefits export manifest" do
    post generate_payroll_run_benefits_export_path(@payroll_run)

    assert_redirected_to payroll_run_benefits_export_path(@payroll_run)
    batch = @payroll_run.reload.metadata.fetch("benefits_export")
    assert_match(/\Avitable_benefits_#{@payroll_run.id}_/, batch.fetch("batch_id"))
    assert_equal "needs_review", batch.fetch("status")
    assert_equal 1, batch.fetch("line_count")
    assert_equal 2, batch.fetch("holdback_count")
    assert_equal @plan.monthly_premium_cents, batch.fetch("total_cents")
    assert_equal @employee.full_name, batch.fetch("lines").first.fetch("employee_name")
  end

  test "benefits enrollment workspace exposes review and sync DTOs" do
    detail = Benefits::EnrollmentDetailQuery.new.call(@pending_enrollment.id)

    assert_instance_of Benefits::EnrollmentDetailDto, detail
    assert_instance_of Benefits::EnrollmentPreflightCheckDto, detail.preflight_checks.first
    assert_instance_of Benefits::EnrollmentTimelineItemDto, detail.timeline.first
    assert_equal @pending_plan.name, detail.benefit_plan_name

    get enrollment_path(@pending_enrollment)

    assert_response :success
    assert_select "h1", @pending_plan.name
    assert_select "h2", "Enrollment preflight"
    assert_select "h2", "Payroll deductions"
    assert_select "h2", "Sync payload"
  end

  test "benefits eligibility center exposes member and dependent DTOs" do
    detail = Benefits::EligibilityQuery.new.call

    assert_instance_of Benefits::EligibilityCenterDto, detail
    assert_instance_of Benefits::EligibilityMetricDto, detail.metrics.first
    assert_instance_of Benefits::EligibilityMemberDto, detail.members.first
    assert_instance_of Benefits::EligibilityDependentDto, detail.dependents.first
    assert_instance_of Benefits::EligibilityIssueDto, detail.issues.first
    assert detail.ready_members.any? { |member| member.enrollment_id == @enrollment.id }
    assert detail.review_dependents.any? { |dependent| dependent.id == @dependent_holdback.id }

    get benefits_eligibility_path

    assert_response :success
    assert_select "h1", "Benefits eligibility sync"
    assert_select "h2", "Member eligibility ledger"
    assert_select "h2", "Eligibility issues"
    assert_select "h2", "Dependent roster"
    assert_select "h2", "Eligibility batch ledger"
  end

  test "generates a benefits eligibility batch through command action" do
    post generate_benefits_eligibility_batch_path

    assert_redirected_to benefits_eligibility_path
    batch = @employer.reload.settings.fetch("vitable_eligibility_batch")
    assert_match(/\Avitable_eligibility_#{@employer.id}_/, batch.fetch("batch_id"))
    assert_equal "ops_console", batch.fetch("requested_by")
    assert_equal 2, batch.fetch("totals").fetch("member_count")
    assert_equal 1, batch.fetch("totals").fetch("employee_count")
    assert_equal 1, batch.fetch("totals").fetch("dependent_count")
    assert_equal 3, batch.fetch("totals").fetch("holdback_count")
    assert_equal @employee.full_name, batch.fetch("members").first.fetch("name")

    detail = Benefits::EligibilityQuery.new.call
    assert_instance_of Benefits::EligibilityBatchDto, detail.latest_batch
    assert_instance_of Benefits::EligibilityBatchMemberDto, detail.batch_members.first
    assert_instance_of Benefits::EligibilityBatchHoldbackDto, detail.batch_holdbacks.first
  end

  test "dependent verification center exposes dependent readiness DTOs" do
    @pending_document.update!(status: "complete", verified_at: 1.hour.ago)
    detail = Benefits::DependentVerificationQuery.new.call

    assert_instance_of Benefits::DependentVerificationCenterDto, detail
    assert_instance_of Benefits::DependentVerificationMetricDto, detail.metrics.first
    assert_instance_of Benefits::DependentVerificationDependentDto, detail.dependents.first
    assert_instance_of Benefits::DependentVerificationRecordDto, detail.verifications.first
    assert_instance_of Benefits::DependentVerificationIssueDto, detail.issues.first
    assert detail.reviewable_verifications.any? { |verification| verification.id == @dependent_verification.id }

    get benefits_dependent_verifications_path

    assert_response :success
    assert_select "h1", "Dependent verification center"
    assert_select "h2", "Dependent roster"
    assert_select "h2", "Readiness issues"
    assert_select "h2", "Verification review queue"
    assert_select "h2", "Packet dependents"
    assert_select "h2", "Packet holdbacks"
  end

  test "requests missing dependent verifications through command action" do
    assert_difference -> { DependentVerification.count }, 1 do
      post request_dependent_verifications_path, params: { requested_by: "benefits_admin" }
    end

    assert_redirected_to benefits_dependent_verifications_path
    verification = @dependent_holdback.dependent_verifications.sole
    assert_equal "birth_certificate", verification.verification_type
    assert_equal "requested", verification.status
    assert_equal "benefits_admin", verification.metadata.fetch("requested_by")
    assert_equal "dependent_verification_center", verification.metadata.fetch("requested_from")
  end

  test "approves a dependent verification through command action" do
    @pending_document.update!(status: "complete", verified_at: 1.hour.ago)

    post approve_dependent_verification_path(@dependent_verification), params: { reviewed_by: "benefits_admin" }

    assert_redirected_to benefits_dependent_verifications_path
    @dependent_verification.reload
    @dependent.reload
    assert_equal "approved", @dependent_verification.status
    assert_equal "benefits_admin", @dependent_verification.reviewed_by
    assert_equal "enrolled", @dependent.enrollment_status
    assert_equal "eligible", @dependent.eligibility_status
  end

  test "rejects a dependent verification through command action" do
    verification = @dependent_holdback.dependent_verifications.create!(
      employee_document: @pending_document,
      verification_type: "birth_certificate",
      status: "needs_review",
      requested_on: Date.current - 3.days,
      due_on: Date.current + 11.days
    )

    post reject_dependent_verification_path(verification), params: { reviewed_by: "benefits_admin", issue_code: "document_mismatch", note: "Document mismatch" }

    assert_redirected_to benefits_dependent_verifications_path
    verification.reload
    @dependent_holdback.reload
    assert_equal "rejected", verification.status
    assert_equal "benefits_admin", verification.reviewed_by
    assert_equal "document_mismatch", verification.issue_code
    assert_equal "Document mismatch", verification.note
    assert_equal "needs_review", @dependent_holdback.eligibility_status
  end

  test "generates a dependent verification packet with ready dependents and holdbacks" do
    @pending_document.update!(status: "complete", verified_at: 1.hour.ago)
    @dependent_verification.update!(status: "approved", reviewed_at: 1.hour.ago, reviewed_by: "benefits_admin")

    post generate_dependent_verification_packet_path, params: { requested_by: "benefits_admin" }

    assert_redirected_to benefits_dependent_verifications_path
    packet = @employer.reload.settings.fetch("dependent_verification_packet")
    assert_match(/\Adependent_verification_#{@employer.id}_/, packet.fetch("packet_id"))
    assert_equal "benefits_admin", packet.fetch("requested_by")
    assert_equal 2, packet.fetch("totals").fetch("dependent_count")
    assert_equal 1, packet.fetch("totals").fetch("ready_count")
    assert_equal 1, packet.fetch("totals").fetch("holdback_count")
    assert_equal @dependent.id, packet.fetch("dependents").first.fetch("dependent_id")
    assert_equal @dependent_holdback.id, packet.fetch("holdbacks").first.fetch("dependent_id")

    detail = Benefits::DependentVerificationQuery.new.call
    assert_instance_of Benefits::DependentVerificationPacketDto, detail.packet
    assert_instance_of Benefits::DependentVerificationPacketLineDto, detail.packet_lines.first
    assert_instance_of Benefits::DependentVerificationIssueDto, detail.packet_holdbacks.first
  end

  test "benefits offboarding workspace exposes coverage termination DTOs" do
    detail = Benefits::OffboardingQuery.new.call

    assert_instance_of Benefits::OffboardingCenterDto, detail
    assert_instance_of Benefits::OffboardingMetricDto, detail.metrics.first
    assert_instance_of Benefits::OffboardingEventDto, detail.events.first
    assert_instance_of Benefits::OffboardingCoverageLineDto, detail.coverage_lines.first
    assert_instance_of Benefits::OffboardingIssueDto, detail.issues.first
    assert detail.events.any? { |event| event.id == @approved_lifecycle_event.id }

    get benefits_offboarding_path

    assert_response :success
    assert_select "h1", "Benefits offboarding"
    assert_select "h2", "Termination queue"
    assert_select "h2", "Offboarding blockers"
    assert_select "h2", "Coverage termination lines"
    assert_select "h2", "Packet termination lines"
    assert_select "h2", "Packet holdbacks"
  end

  test "generates a benefits offboarding packet through command action" do
    @employee.update!(vitable_id: "empl_ops_casey")
    @enrollment.update!(vitable_id: "enrl_ops_primary")
    @dependent.update!(vitable_id: "dep_ops_harper")

    post generate_benefits_offboarding_packet_path, params: { requested_by: "benefits_admin" }

    assert_redirected_to benefits_offboarding_path
    packet = @employer.reload.settings.fetch("benefits_offboarding_packet")
    assert_match(/\Abenefits_offboarding_#{@employer.id}_/, packet.fetch("packet_id"))
    assert_equal "benefits_admin", packet.fetch("requested_by")
    assert_equal "ready", packet.fetch("status")
    assert_equal 1, packet.fetch("totals").fetch("event_count")
    assert_equal 2, packet.fetch("totals").fetch("member_count")
    assert_equal 1, packet.fetch("totals").fetch("employee_count")
    assert_equal 0, packet.fetch("totals").fetch("holdback_count")
    assert_equal "/v1/employers/:employer_id/census-sync", packet.fetch("endpoint")
    assert_equal "omit_employee_from_next_census_sync", packet.fetch("deactivation_strategy")
    assert_equal "employee", packet.fetch("terminations").first.fetch("member_type")

    detail = Benefits::OffboardingQuery.new.call
    assert_instance_of Benefits::OffboardingPacketDto, detail.packet
    assert_instance_of Benefits::OffboardingCoverageLineDto, detail.packet_lines.first
    assert_empty detail.packet_holdbacks
  end

  test "benefits reconciliation workspace exposes deduction exception DTOs" do
    @pending_deduction.update!(amount_cents: 1_234, status: "ready")

    detail = Benefits::ReconciliationQuery.new.call

    assert_instance_of Benefits::ReconciliationDetailDto, detail
    assert_instance_of Benefits::ReconciliationMetricDto, detail.metrics.first
    assert_instance_of Benefits::ReconciliationItemDto, detail.items.first
    assert detail.exception_items.any? { |item| item.enrollment_id == @pending_enrollment.id }

    get benefits_reconciliation_path

    assert_response :success
    assert_select "h1", "Benefits deduction reconciliation"
    assert_select "h2", "Exception queue"
    assert_select "h2", "Enrollment deduction ledger"
    assert_select "td", text: @pending_plan.name
  end

  test "webhook event workspace exposes replay diagnostics" do
    detail = Vitable::WebhookEventDetailQuery.new.call(@webhook_event.id)

    assert_instance_of Vitable::WebhookEventDetailDto, detail
    assert_instance_of Operations::IntegrationConnectionDto, detail.connection
    assert_instance_of Vitable::WebhookPreflightCheckDto, detail.preflight_checks.first
    assert_instance_of Vitable::WebhookTimelineItemDto, detail.timeline.first
    assert_empty detail.deliveries

    get webhook_event_path(@webhook_event)

    assert_response :success
    assert_select "h1", @webhook_event.event_name
    assert_select "h2", "Replay preflight"
    assert_select "h2", "Stored payload"
    assert_select "h2", "Delivery attempts"
    assert_select "h2", "Event timeline"
    assert_select "h2", "Sync attempts"
    assert_select "p", "Signature"
    assert_select "button", "Refresh deliveries"
  end

  test "refreshes webhook deliveries as missing credentials sync run without API key" do
    assert_difference -> { @connection.sync_runs.where(operation: "webhook_delivery_refresh").count }, 1 do
      post refresh_deliveries_webhook_event_path(@webhook_event), params: { requested_by: "integration_admin" }
    end

    assert_redirected_to webhook_event_path(@webhook_event)
    sync = @connection.sync_runs.where(operation: "webhook_delivery_refresh").recent_first.first
    assert_equal "needs_credentials", sync.status
    assert_match @connection.api_key_reference, sync.error_message
    assert_equal "integration_admin", sync.stats.fetch("requested_by")
    assert_equal @webhook_event.event_id, sync.stats.fetch("resource_id")
  end

  test "successful webhook delivery refresh stores delivery snapshot DTOs" do
    response_class = Data.define(:data)
    gateway_class = Class.new do
      define_method(:initialize) { |_connection| }
      define_method(:list_webhook_event_deliveries) do |event_id|
        response_class.new(
          data: [
            {
              id: "wdlv_ops_123",
              webhook_event_id: event_id,
              subscription_id: "wsub_ops_123",
              status: "Delivered",
              created_at: Time.current,
              started_at: Time.current,
              delivered_at: Time.current,
              failed_at: nil,
              failure_reason: ""
            }
          ]
        )
      end
    end
    previous_key = ENV[@connection.api_key_reference]
    ENV[@connection.api_key_reference] = "vit_apk_test_value"

    result = Vitable::RefreshWebhookDeliveriesCommand.new(
      dto: Vitable::RefreshWebhookDeliveriesDto.new(webhook_event_id: @webhook_event.id, requested_by: "integration_admin"),
      gateway_class:
    ).call

    assert result.success?
    snapshot = @webhook_event.reload.metadata.fetch("delivery_snapshot")
    assert_equal 1, snapshot.fetch("delivery_count")
    assert_equal "wdlv_ops_123", snapshot.fetch("deliveries").first.fetch("id")
    detail = Vitable::WebhookEventDetailQuery.new.call(@webhook_event.id)
    assert_instance_of Vitable::WebhookDeliveryDto, detail.deliveries.first
    assert_equal "delivered", detail.deliveries.first.status_key
  ensure
    ENV[@connection.api_key_reference] = previous_key
  end

  test "webhook delivery refresh fails when remote delivery omits id" do
    response_class = Data.define(:data)
    gateway_class = Class.new do
      define_method(:initialize) { |_connection| }
      define_method(:list_webhook_event_deliveries) do |event_id|
        response_class.new(
          data: [
            {
              webhook_event_id: event_id,
              subscription_id: "wsub_ops_123",
              status: "Delivered",
              created_at: Time.current,
              api_key: "vit_apk_should_not_persist"
            }
          ]
        )
      end
    end
    previous_key = ENV[@connection.api_key_reference]
    ENV[@connection.api_key_reference] = "vit_apk_test_value"

    result = Vitable::RefreshWebhookDeliveriesCommand.new(
      dto: Vitable::RefreshWebhookDeliveriesDto.new(webhook_event_id: @webhook_event.id, requested_by: "integration_admin"),
      gateway_class:
    ).call

    assert result.failure?
    assert_nil @webhook_event.reload.metadata.to_h.fetch("delivery_snapshot", nil)
    sync = @connection.sync_runs.where(operation: "webhook_delivery_refresh").recent_first.first
    assert_equal "failed", sync.status
    assert_match "remote delivery ID", sync.error_message
    assert_equal "ArgumentError", sync.stats.fetch("error_class")
    assert_equal "wsub_ops_123", sync.stats.dig("remote_response", "data", 0, "subscription_id")
    assert_equal "[FILTERED]", sync.stats.dig("remote_response", "data", 0, "api_key")
    assert_match "remote delivery ID", result.errors.to_sentence
  ensure
    ENV[@connection.api_key_reference] = previous_key
  end

  test "webhook delivery refresh fails when remote delivery belongs to another event" do
    response_class = Data.define(:data)
    gateway_class = Class.new do
      define_method(:initialize) { |_connection| }
      define_method(:list_webhook_event_deliveries) do |_event_id|
        response_class.new(
          data: [
            {
              id: "wdlv_ops_123",
              webhook_event_id: "wevt_other",
              subscription_id: "wsub_ops_123",
              status: "Delivered",
              created_at: Time.current
            }
          ]
        )
      end
    end
    previous_key = ENV[@connection.api_key_reference]
    ENV[@connection.api_key_reference] = "vit_apk_test_value"

    result = Vitable::RefreshWebhookDeliveriesCommand.new(
      dto: Vitable::RefreshWebhookDeliveriesDto.new(webhook_event_id: @webhook_event.id, requested_by: "integration_admin"),
      gateway_class:
    ).call

    assert result.failure?
    assert_nil @webhook_event.reload.metadata.to_h.fetch("delivery_snapshot", nil)
    sync = @connection.sync_runs.where(operation: "webhook_delivery_refresh").recent_first.first
    assert_equal "failed", sync.status
    assert_match "expected #{@webhook_event.event_id}", sync.error_message
    assert_equal "ArgumentError", sync.stats.fetch("error_class")
    assert_equal "wevt_other", sync.stats.dig("remote_response", "data", 0, "webhook_event_id")
    assert_match "expected #{@webhook_event.event_id}", result.errors.to_sentence
  ensure
    ENV[@connection.api_key_reference] = previous_key
  end

  test "unsupported Vitable resource fetches are recorded as failed sync runs" do
    previous_key = ENV[@connection.api_key_reference]
    ENV[@connection.api_key_reference] = "vit_apk_test_value"

    result = Vitable::FetchResourceCommand.new(
      dto: Vitable::FetchResourceDto.new(connection_id: @connection.id, resource_type: "benefit_plan", resource_id: "bpln_ops_123")
    ).call

    assert result.failure?
    sync = @connection.sync_runs.where(resource_type: "benefit_plan", operation: "fetch").recent_first.first
    assert_equal "failed", sync.status
    assert_match "does not expose a retrieve endpoint", sync.error_message
  ensure
    ENV[@connection.api_key_reference] = previous_key
  end

  test "integration connection workspace exposes credential and coverage DTOs" do
    @employer.update!(
      vitable_id: "empr_ops_123",
      settings: @employer.settings.to_h.merge(Vitable::CareGroupRepository::GROUP_ID_KEY => "grp_ops_123")
    )
    @employee.update!(vitable_id: "empl_ops_casey")
    @enrollment.update!(vitable_id: "enrl_ops_primary_care")

    detail = Vitable::ConnectionDetailQuery.new.call(@connection.id)

    assert_instance_of Vitable::ConnectionDetailDto, detail
    assert_instance_of Vitable::ConnectionMetricDto, detail.metrics.first
    assert_instance_of Vitable::ConnectionHealthCheckDto, detail.health_checks.first
    assert_instance_of Vitable::EndpointCoverageDto, detail.endpoint_coverage.first
    assert_instance_of Vitable::ConnectionTimelineItemDto, detail.timeline.first
    assert_instance_of Vitable::ApiSnapshotDto, detail.api_snapshot
    assert_instance_of Vitable::WebhookSimulatorDto, detail.simulator
    assert_instance_of Vitable::WebhookSimulationEventOptionDto, detail.simulator.event_options.first
    assert_equal 10, detail.simulator.event_options.count
    assert_equal %w[enrollment employee], detail.simulator.resource_options
    event_names = detail.simulator.event_options.map(&:event_name)
    sdk_event_names = VitableConnect::WebhookEventListParams::EventName.values.map(&:to_s)
    assert_includes event_names, "employee.deduction_created"
    assert_not_includes event_names, "group.updated"
    assert_not_includes event_names, "benefit_plan.updated"
    assert_empty event_names - sdk_event_names
    assert_equal "enrl_ops_primary_care", detail.simulator.default_resource_id
    assert_equal "empl_ops_casey", detail.simulator.event_options.find { |option| option.resource_type == "employee" }.sample_resource_id
    assert_equal [
      "auth tokens",
      "employers",
      "employer settings",
      "eligibility policies",
      "census sync",
      "remote roster",
      "employees",
      "employee enrollments",
      "enrollments",
      "plans",
      "groups",
      "group member sync",
      "webhook events"
    ], detail.endpoint_coverage.map(&:resource_type)
    employee_coverage = detail.endpoint_coverage.find { |coverage| coverage.resource_type == "employees" }
    assert_operator employee_coverage.activity_count, :>=, 2
    groups_coverage = detail.endpoint_coverage.find { |coverage| coverage.resource_type == "groups" }
    assert_equal "pending", groups_coverage.status

    employer_fetch_log = @connection.api_request_logs.create!(
      operation: "employer.retrieve",
      method: "GET",
      path: "/v1/employers/empr_ops_123",
      status_code: 200,
      duration_ms: 39
    )
    detail_with_employer_fetch = Vitable::ConnectionDetailQuery.new.call(@connection.id)
    employer_coverage = detail_with_employer_fetch.endpoint_coverage.find { |coverage| coverage.resource_type == "employers" }
    assert_equal "ready", employer_coverage.status
    assert_operator employer_coverage.activity_count, :>=, 1
    assert_equal employer_fetch_log.created_at.to_i, employer_coverage.last_seen_at.to_i

    blocked_member_sync = @connection.sync_runs.create!(
      resource_type: "group",
      operation: "care_member_sync_submit",
      status: "blocked",
      started_at: Time.current,
      completed_at: Time.current,
      error_message: "Remote Vitable care group ID is missing",
      stats: { resource_id: "care_group_pending" }
    )
    detail_with_blocked_member_sync = Vitable::ConnectionDetailQuery.new.call(@connection.id)
    member_sync_coverage = detail_with_blocked_member_sync.endpoint_coverage.find { |coverage| coverage.resource_type == "group member sync" }
    assert_equal "blocked", member_sync_coverage.status
    assert_equal blocked_member_sync.completed_at.to_i, member_sync_coverage.last_seen_at.to_i

    group_fetch_run = @connection.sync_runs.create!(
      resource_type: "group",
      operation: "fetch",
      status: "succeeded",
      started_at: Time.current,
      completed_at: Time.current,
      stats: { resource_id: "grp_ops_123" }
    )
    detail_with_group_fetch = Vitable::ConnectionDetailQuery.new.call(@connection.id)
    groups_coverage = detail_with_group_fetch.endpoint_coverage.find { |coverage| coverage.resource_type == "groups" }
    assert_equal "ready", groups_coverage.status
    assert_equal group_fetch_run.completed_at.to_i, groups_coverage.last_seen_at.to_i

    group_event = @connection.webhook_events.create!(
      event_id: "wevt_ops_group_updated",
      organization_external_id: @organization.external_id,
      event_name: "group.updated",
      resource_type: "group",
      resource_id: "grp_ops_123",
      occurred_at: Time.current,
      status: "processed",
      processed_at: Time.current,
      payload: { "event_id" => "wevt_ops_group_updated" }
    )
    detail_with_group_event = Vitable::ConnectionDetailQuery.new.call(@connection.id)
    groups_coverage = detail_with_group_event.endpoint_coverage.find { |coverage| coverage.resource_type == "groups" }
    assert_equal "ready", groups_coverage.status
    assert_equal group_event.created_at.to_i, groups_coverage.last_seen_at.to_i
    assert_equal @sync_run.id, detail.sync_runs.first.id
    assert_equal @request_log.id, detail.request_logs.first.id
    assert_not detail.webhook_secret_present

    get integration_connection_path(@connection)

    assert_response :success
    assert_select "h1", "#{@organization.name} Vitable connection"
    assert_select "h2", "Remote API snapshot"
    assert_select "h2", "Test event composer"
    assert_select "h2", "Readiness checks"
    assert_select "h2", "API coverage"
    assert_select "h2", "Connection timeline"
    assert_select "h2", "Webhook queue"
    assert_select "h2", "Connection activity"
  end

  test "integration connection workspace uses API snapshot ids for webhook composer defaults" do
    @connection.update!(
      metadata: {
        "api_snapshot" => {
          "employers" => [ { "id" => "empr_snapshot_123", "name" => "Snapshot Employer" } ],
          "groups" => [ { "id" => "grp_snapshot_123", "name" => "Snapshot Group" } ],
          "remote_employee_rosters" => [
            {
              "remote_employer_id" => "empr_snapshot_123",
              "employees" => [ { "id" => "empl_snapshot_123", "email" => "casey@example.com" } ]
            }
          ],
          "employee_enrollments" => [
            {
              "remote_employee_id" => "empl_snapshot_123",
              "enrollments" => [ { "id" => "enrl_snapshot_123", "status" => "accepted" } ]
            }
          ]
        }
      }
    )

    detail = Vitable::ConnectionDetailQuery.new.call(@connection.id)

    assert_equal "enrl_snapshot_123", detail.simulator.default_resource_id
    assert_equal "empl_snapshot_123", detail.simulator.event_options.find { |option| option.resource_type == "employee" }.sample_resource_id
  end

  test "refreshes Vitable API snapshot as missing credentials sync run without API key" do
    assert_difference -> { @connection.sync_runs.where(operation: "api_snapshot_refresh").count }, 1 do
      post refresh_api_snapshot_integration_connection_path(@connection), params: { requested_by: "integration_admin" }
    end

    assert_redirected_to integration_connection_path(@connection)
    sync = @connection.sync_runs.where(operation: "api_snapshot_refresh").recent_first.first
    assert_equal "needs_credentials", sync.status
    assert_match @connection.api_key_reference, sync.error_message
    assert_equal "integration_admin", sync.stats.fetch("requested_by")
    assert_equal "needs_credentials", @connection.reload.status
  end

  test "successful Vitable API snapshot refresh stores remote read counts" do
    @employee.update!(vitable_id: "empl_remote_casey")
    existing_event = @connection.webhook_events.create!(
      event_id: "wevt_existing_remote",
      organization_external_id: @organization.external_id,
      event_name: "enrollment.enrolled",
      resource_type: "enrollment",
      resource_id: "enrl_existing",
      occurred_at: 1.hour.ago,
      status: "processed",
      processed_at: 30.minutes.ago,
      payload: { "event_id" => "wevt_existing_remote" },
      metadata: { "processed_by" => "fixture" }
    )
    remote_webhook_events = [
      {
        id: "wevt_remote_123",
        organization_id: @organization.external_id,
        event_name: "employee.eligibility_granted",
        resource_type: "employee",
        resource_id: "empl_remote_casey",
        created_at: 2.minutes.ago.iso8601
      },
      {
        id: existing_event.event_id,
        organization_id: @organization.external_id,
        event_name: existing_event.event_name,
        resource_type: existing_event.resource_type,
        resource_id: existing_event.resource_id,
        created_at: existing_event.occurred_at.iso8601
      },
      {
        id: "wevt_other_org",
        organization_id: "org_other_vitable",
        event_name: "group.updated",
        resource_type: "group",
        resource_id: "grp_other",
        created_at: 1.minute.ago.iso8601
      },
      {
        id: "wevt_missing_org",
        event_name: "employee.eligibility_granted",
        resource_type: "employee",
        resource_id: "empl_missing_org",
        created_at: 90.seconds.ago.iso8601
      },
      {
        id: "wevt_incomplete_remote",
        event_name: "employee.updated"
      }
    ]
    response_class = Data.define(:data)
    gateway_class = Class.new do
      define_method(:initialize) { |_connection| }
      define_method(:list_all_employers) { response_class.new(data: [ { id: "empr_ops_123", name: "Atlas Global Services" } ]) }
      define_method(:list_all_groups) { response_class.new(data: [ { id: "grp_ops_123", name: "Atlas Care Group" } ]) }
      define_method(:list_all_plans) { response_class.new(data: [ { id: "plan_dpc", name: "Direct Primary Care" }, { id: "plan_mec", name: "MEC" } ]) }
      define_method(:list_all_webhook_events) { |**_filters| response_class.new(data: remote_webhook_events) }
      define_method(:list_all_employee_enrollments) do |employee_id|
        response_class.new(
          data: [
            { id: "enrl_remote_123", employee_id:, benefit: { id: "plan_dpc", name: "Direct Primary Care" }, status: "pending" }
          ]
        )
      end
      define_method(:fetch_resource) do |resource_type, resource_id|
        raise ArgumentError, "unexpected resource fetch #{resource_type}:#{resource_id}" unless resource_type == "employee" && resource_id == "empl_remote_casey"

        {
          data: {
            id: resource_id,
            reference_id: "musto_employee_#{Employee.find_by!(email: "casey@example.com").id}",
            email: "casey@example.com",
            status: "active",
            member_id: "mem_remote_casey"
          }
        }
      end
    end
    previous_key = ENV[@connection.api_key_reference]
    ENV[@connection.api_key_reference] = "vit_apk_test_value"

    assert_difference -> { WebhookEvent.count }, 1 do
      result = Vitable::RefreshApiSnapshotCommand.new(
        dto: Vitable::RefreshApiSnapshotDto.new(connection_id: @connection.id, requested_by: "integration_admin"),
        gateway_class:
      ).call

      assert result.success?, result.errors.to_sentence
    end

    snapshot = @connection.reload.metadata.fetch("api_snapshot")
    assert_equal 1, snapshot.dig("counts", "remote_employer_count")
    assert_equal 1, snapshot.dig("counts", "remote_group_count")
    assert_equal 2, snapshot.dig("counts", "remote_plan_count")
    assert_equal 5, snapshot.dig("counts", "remote_webhook_event_count")
    assert_equal 1, snapshot.dig("counts", "imported_webhook_event_count")
    assert_equal 1, snapshot.dig("counts", "existing_webhook_event_count")
    assert_equal 1, snapshot.dig("counts", "webhook_recovery_candidate_count")
    assert_equal 1, snapshot.dig("counts", "recovered_webhook_event_count")
    assert_equal 0, snapshot.dig("counts", "failed_webhook_recovery_count")
    assert_equal 0, snapshot.dig("counts", "skipped_webhook_recovery_count")
    assert_equal 1, snapshot.dig("counts", "remote_employee_enrollment_count")
    assert_equal @employee.id, snapshot.fetch("employee_enrollments").first.fetch("local_employee_id")
    assert_equal 3, snapshot.dig("webhook_event_ingestion", "skipped_count")
    assert_includes snapshot.dig("webhook_event_ingestion", "skipped_event_ids"), "wevt_incomplete_remote"
    assert_includes snapshot.dig("webhook_event_ingestion", "skipped_event_ids"), "wevt_missing_org"
    assert_includes snapshot.dig("webhook_event_ingestion", "skipped_event_ids"), "wevt_other_org"
    skipped_missing_org = snapshot.dig("webhook_event_ingestion", "skipped_events").find { |event| event.fetch("event_id") == "wevt_missing_org" }
    assert_equal "incomplete_event", skipped_missing_org.fetch("reason")
    skipped_other_org = snapshot.dig("webhook_event_ingestion", "skipped_events").find { |event| event.fetch("event_id") == "wevt_other_org" }
    assert_equal "organization_mismatch", skipped_other_org.fetch("reason")
    assert_equal "org_other_vitable", skipped_other_org.fetch("organization_id")
    assert_equal @organization.external_id, skipped_other_org.fetch("expected_organization_id")

    imported_event = WebhookEvent.find_by!(event_id: "wevt_remote_123")
    assert_equal @connection.id, imported_event.integration_connection_id
    assert_equal "processed", imported_event.status
    assert imported_event.processed_at.present?
    assert_equal "employee.eligibility_granted", imported_event.event_name
    assert_equal "vitable_webhook_events_api", imported_event.metadata.dig("remote_webhook_event_snapshot", "source")
    reconciliation = imported_event.metadata.fetch("resource_reconciliation")
    assert_equal "matched", reconciliation.fetch("status")
    assert_includes reconciliation.fetch("applied_changes"), "metadata.vitable_last_webhook_event_name"
    assert_equal "active", @employee.reload.metadata.fetch("vitable_remote_status")
    assert_equal "mem_remote_casey", @employee.metadata.fetch("vitable_member_id")

    assert_equal "processed", existing_event.reload.status
    assert existing_event.processed_at.present?
    assert_equal "vitable_webhook_events_api", existing_event.metadata.dig("remote_webhook_event_snapshot", "source")
    assert_nil WebhookEvent.find_by(event_id: "wevt_other_org")

    sync = @connection.sync_runs.where(operation: "api_snapshot_refresh").recent_first.first
    assert_equal 1, sync.stats.dig("webhook_event_ingestion", "created_count")
    assert_equal 1, sync.stats.dig("webhook_event_ingestion", "existing_count")
    assert_equal 3, sync.stats.dig("webhook_event_ingestion", "skipped_count")
    assert_equal 1, sync.stats.dig("webhook_event_recovery", "processed_count")
    assert_includes sync.stats.dig("webhook_event_recovery", "processed_event_ids"), "wevt_remote_123"

    detail = Vitable::ConnectionDetailQuery.new.call(@connection.id)
    assert_equal 1, detail.api_snapshot.imported_webhook_event_count
    assert_equal 1, detail.api_snapshot.existing_webhook_event_count
    assert_equal 1, detail.api_snapshot.recovered_webhook_event_count
  ensure
    ENV[@connection.api_key_reference] = previous_key
  end

  test "Vitable API snapshot refresh scopes webhook events to the previous snapshot window" do
    previous_refreshed_at = 3.hours.ago.change(usec: 0)
    @connection.update!(
      metadata: @connection.metadata.to_h.merge(
        "api_snapshot" => {
          "refreshed_at" => previous_refreshed_at.iso8601
        }
      )
    )
    response_class = Data.define(:data)
    webhook_filters = []
    gateway_class = Class.new do
      define_method(:initialize) { |_connection| }
      define_method(:list_all_employers) { response_class.new(data: []) }
      define_method(:list_all_groups) { response_class.new(data: []) }
      define_method(:list_all_plans) { response_class.new(data: []) }
      define_method(:list_all_webhook_events) do |**filters|
        webhook_filters << filters
        response_class.new(data: [])
      end
      define_method(:list_all_employer_employees) { |_employer_id| response_class.new(data: []) }
      define_method(:list_all_employee_enrollments) { |_employee_id| response_class.new(data: []) }
    end
    previous_key = ENV[@connection.api_key_reference]
    ENV[@connection.api_key_reference] = "vit_apk_test_value"

    before_refresh = Time.current
    result = Vitable::RefreshApiSnapshotCommand.new(
      dto: Vitable::RefreshApiSnapshotDto.new(connection_id: @connection.id, requested_by: "integration_admin"),
      gateway_class:
    ).call
    after_refresh = Time.current

    assert result.success?
    assert_equal 1, webhook_filters.count
    expected_created_after = previous_refreshed_at - Vitable::RefreshApiSnapshotCommand::WEBHOOK_EVENT_LOOKBACK
    created_before = webhook_filters.first.fetch(:created_before)
    assert_equal expected_created_after.to_i, webhook_filters.first.fetch(:created_after).to_i
    assert_operator created_before, :>=, before_refresh
    assert_operator created_before, :<=, after_refresh

    snapshot = @connection.reload.metadata.fetch("api_snapshot")
    assert_equal expected_created_after.iso8601, snapshot.dig("webhook_event_query", "created_after")
    assert_equal created_before.iso8601, snapshot.dig("webhook_event_query", "created_before")
    assert_equal created_before.iso8601, snapshot.fetch("refreshed_at")
    assert snapshot.fetch("completed_at").present?
    assert_equal 0, snapshot.dig("counts", "remote_webhook_event_count")
  ensure
    ENV[@connection.api_key_reference] = previous_key
  end

  test "Vitable API snapshot refresh reconciles employee enrollments and payroll deductions" do
    @employee.update!(vitable_id: "empl_ops_casey")
    answered_at = Time.current.change(usec: 0)
    coverage_start = Date.current.beginning_of_month
    response_class = Data.define(:data)
    gateway_class = Class.new do
      define_method(:initialize) { |_connection| }
      define_method(:list_all_employers) { response_class.new(data: [ { id: "empr_ops_123", name: "Atlas Global Services" } ]) }
      define_method(:list_all_groups) { response_class.new(data: []) }
      define_method(:list_all_plans) { response_class.new(data: [ { id: "bprd_remote_dental", name: "Dental" } ]) }
      define_method(:list_all_webhook_events) { |**_filters| response_class.new(data: []) }
      define_method(:list_all_employee_enrollments) do |employee_id|
        response_class.new(
          data: [
            {
              id: "enrl_remote_dental",
              employee_id:,
              benefit: { id: "bprd_remote_dental", name: "Dental", category: "Dental" },
              status: "enrolled",
              answered_at:,
              coverage_start:,
              employee_deduction_in_cents: 4500,
              employer_contribution_in_cents: 500
            }
          ]
        )
      end
    end
    previous_key = ENV[@connection.api_key_reference]
    ENV[@connection.api_key_reference] = "vit_apk_test_value"

    result = Vitable::RefreshApiSnapshotCommand.new(
      dto: Vitable::RefreshApiSnapshotDto.new(connection_id: @connection.id, requested_by: "integration_admin"),
      gateway_class:
    ).call

    assert result.success?
    @pending_plan.reload
    @pending_enrollment.reload
    @pending_deduction.reload
    snapshot = @connection.reload.metadata.fetch("api_snapshot")

    assert_equal "bprd_remote_dental", @pending_plan.vitable_id
    assert_equal "vitable_api_snapshot", @pending_plan.metadata.dig("vitable_plan_mapping", "matched_by")
    assert_equal "enrl_remote_dental", @pending_enrollment.vitable_id
    assert_equal "accepted", @pending_enrollment.status
    assert_equal answered_at.to_i, @pending_enrollment.accepted_at.to_i
    assert_equal coverage_start, @pending_enrollment.effective_on
    assert_equal "enrolled", @pending_enrollment.metadata.fetch("vitable_remote_status")
    assert_equal "bprd_remote_dental", @pending_enrollment.metadata.fetch("vitable_remote_plan_id")
    assert_equal 4500, @pending_enrollment.metadata.fetch("vitable_employee_deduction_cents")
    assert_equal 4500, @pending_deduction.amount_cents
    assert_equal "ready", @pending_deduction.status
    assert_equal "vitable_api_snapshot", @pending_deduction.metadata.fetch("source")
    assert_equal "enrl_remote_dental", @pending_deduction.metadata.fetch("raw_payload").fetch("enrollment_id")
    assert_equal 1, snapshot.dig("counts", "mapped_plan_count")
    assert_equal 2, snapshot.dig("counts", "unmatched_local_plan_count")
    assert_equal 1, snapshot.fetch("plan_reconciliation").first.fetch("mapped_plan_count")
    assert_equal 1, snapshot.dig("counts", "reconciled_enrollment_count")
    assert_equal 1, snapshot.dig("counts", "updated_enrollment_count")
    assert_equal 1, snapshot.dig("counts", "enrollment_deduction_changed_count")
    assert_equal 0, snapshot.dig("counts", "enrollment_missing_plan_count")

    detail = Vitable::ConnectionDetailQuery.new.call(@connection.id)
    assert_equal 1, detail.api_snapshot.mapped_plan_count
    assert_equal 1, detail.api_snapshot.reconciled_enrollment_count
    assert_equal 1, detail.api_snapshot.enrollment_deduction_changed_count
  ensure
    ENV[@connection.api_key_reference] = previous_key
  end

  test "Vitable API snapshot refresh fails when employee enrollment omits remote enrollment id" do
    @employee.update!(vitable_id: "empl_ops_casey")
    response_class = Data.define(:data)
    gateway_class = Class.new do
      define_method(:initialize) { |_connection| }
      define_method(:list_all_employers) { response_class.new(data: []) }
      define_method(:list_all_groups) { response_class.new(data: []) }
      define_method(:list_all_plans) { response_class.new(data: []) }
      define_method(:list_all_webhook_events) { |**_filters| response_class.new(data: []) }
      define_method(:list_all_employee_enrollments) do |employee_id|
        response_class.new(
          data: [
            {
              employee_id:,
              benefit: { id: "bprd_remote_dental", name: "Dental", category: "Dental" },
              status: "enrolled",
              coverage_start: Date.current.beginning_of_month,
              employee_deduction_in_cents: 4500
            }
          ]
        )
      end
    end
    previous_key = ENV[@connection.api_key_reference]
    ENV[@connection.api_key_reference] = "vit_apk_test_value"

    result = Vitable::RefreshApiSnapshotCommand.new(
      dto: Vitable::RefreshApiSnapshotDto.new(connection_id: @connection.id, requested_by: "integration_admin"),
      gateway_class:
    ).call

    assert result.failure?
    assert_nil @pending_enrollment.reload.vitable_id
    assert_nil @connection.reload.metadata.fetch("api_snapshot", nil)
    sync = @connection.sync_runs.where(operation: "api_snapshot_refresh").recent_first.first
    assert_equal "failed", sync.status
    assert_match "remote enrollment ID", sync.error_message
    assert_match "remote enrollment ID", result.errors.to_sentence
  ensure
    ENV[@connection.api_key_reference] = previous_key
  end

  test "Vitable API snapshot refresh fails when list response omits data array" do
    response_class = Data.define(:items)
    gateway_class = Class.new do
      define_method(:initialize) { |_connection| }
      define_method(:list_all_employers) { response_class.new(items: []) }
    end
    previous_key = ENV[@connection.api_key_reference]
    ENV[@connection.api_key_reference] = "vit_apk_test_value"

    result = Vitable::RefreshApiSnapshotCommand.new(
      dto: Vitable::RefreshApiSnapshotDto.new(connection_id: @connection.id, requested_by: "integration_admin"),
      gateway_class:
    ).call

    assert result.failure?
    assert_nil @connection.reload.metadata.fetch("api_snapshot", nil)
    sync = @connection.sync_runs.where(operation: "api_snapshot_refresh").recent_first.first
    assert_equal "failed", sync.status
    assert_match "employer list response", sync.error_message
    assert_match "data array", result.errors.to_sentence
  ensure
    ENV[@connection.api_key_reference] = previous_key
  end

  test "Vitable API snapshot refresh maps remote roster employees before enrollment reads" do
    @employee.update!(employment_status: "terminated")
    response_class = Data.define(:data)
    gateway_class = Class.new do
      define_method(:initialize) { |_connection| }
      define_method(:list_all_employers) do
        response_class.new(
          data: [
            {
              id: "empr_ops_123",
              name: "Ops Employer",
              legal_name: "Ops Employer LLC",
              reference_id: "musto_employer_#{Employer.find_by!(name: "Ops Employer").id}",
              active: true
            }
          ]
        )
      end
      define_method(:list_all_groups) do
        response_class.new(
          data: [
            {
              id: "grp_remote_ops",
              name: "Ops Employer",
              external_reference_id: "musto_care_group_#{Employer.find_by!(name: "Ops Employer").id}",
              organization_id: "org_demo_vitable"
            }
          ]
        )
      end
      define_method(:list_all_plans) { response_class.new(data: []) }
      define_method(:list_all_webhook_events) { |**_filters| response_class.new(data: []) }
      define_method(:list_all_employer_employees) do |employer_id|
        response_class.new(
          data: [
            {
              id: "empl_remote_casey",
              employer_id:,
              reference_id: "musto_employee_#{Employee.find_by!(email: "casey@example.com").id}",
              email: "casey@example.com",
              status: "active",
              member_id: "mem_remote_casey",
              deductions: [
                {
                  id: "ded_remote_dental",
                  benefit_name: "Dental",
                  deduction_amount_in_cents: 4500,
                  frequency: "bi_weekly"
                }
              ]
            }
          ]
        )
      end
      define_method(:list_all_employee_enrollments) do |employee_id|
        response_class.new(data: employee_id == "empl_remote_casey" ? [] : [ { id: "unexpected_employee_id" } ])
      end
    end
    previous_key = ENV[@connection.api_key_reference]
    ENV[@connection.api_key_reference] = "vit_apk_test_value"

    assert_nil @employer.vitable_id
    assert_nil @employer.settings.to_h.fetch("vitable_care_group_id", nil)

    result = Vitable::RefreshApiSnapshotCommand.new(
      dto: Vitable::RefreshApiSnapshotDto.new(connection_id: @connection.id, requested_by: "integration_admin"),
      gateway_class:
    ).call

    assert result.success?
    @employer.reload
    @employee.reload
    @pending_deduction.reload
    snapshot = @connection.reload.metadata.fetch("api_snapshot")
    sync = @connection.sync_runs.where(operation: "api_snapshot_refresh").recent_first.first

    assert_equal "empr_ops_123", @employer.vitable_id
    assert_equal "active", @employer.settings.fetch("vitable_remote_status")
    assert_equal "musto_employer_#{@employer.id}", @employer.settings.fetch("vitable_remote_reference_id")
    assert_equal "grp_remote_ops", @employer.settings.fetch("vitable_care_group_id")
    assert_equal "external_reference_id", @employer.settings.fetch("vitable_care_group_snapshot_matched_by")
    assert_equal "grp_remote_ops", @employer.settings.dig("vitable_care_group_snapshot", "id")
    assert_equal "empl_remote_casey", @employee.vitable_id
    assert_equal "active", @employee.employment_status
    assert_equal "active", @employee.metadata.fetch("vitable_remote_status")
    assert_equal "mem_remote_casey", @employee.metadata.fetch("vitable_member_id")
    assert_equal "musto_employee_#{@employee.id}", @employee.metadata.fetch("vitable_remote_reference_id")
    assert_equal 4500, @pending_deduction.amount_cents
    assert_equal "ready", @pending_deduction.status
    assert_equal "vitable_api_snapshot", @pending_deduction.metadata.fetch("source")
    assert_equal 1, snapshot.dig("counts", "remote_employee_count")
    assert_equal 1, snapshot.dig("counts", "mapped_employer_count")
    assert_equal 0, snapshot.dig("counts", "unmatched_remote_employer_count")
    assert_equal 0, snapshot.dig("counts", "conflicting_remote_employer_count")
    assert_equal 1, snapshot.dig("counts", "mapped_group_count")
    assert_equal 0, snapshot.dig("counts", "unmatched_remote_group_count")
    assert_equal 0, snapshot.dig("counts", "conflicting_remote_group_count")
    assert_equal 1, snapshot.dig("group_reconciliation", "matched_count")
    assert_equal 1, snapshot.dig("counts", "mapped_employee_count")
    assert_equal 0, snapshot.dig("counts", "unmatched_remote_employee_count")
    assert_equal 1, snapshot.dig("counts", "remote_employee_deduction_changed_count")
    assert_equal 1, snapshot.dig("employer_reconciliation", "matched_count")
    assert_equal 1, snapshot.fetch("remote_employee_rosters").first.fetch("employees").count
    assert_equal "empr_ops_123", snapshot.fetch("remote_employee_rosters").first.fetch("remote_employer_id")
    assert_equal "empl_remote_casey", snapshot.fetch("employee_enrollments").first.fetch("remote_employee_id")
    assert_equal 1, sync.stats.fetch("mapped_employer_count")
    assert_equal 1, sync.stats.fetch("mapped_group_count")
    assert_equal 1, sync.stats.fetch("remote_employee_count")
    assert_equal 1, sync.stats.fetch("mapped_employee_count")

    detail = Vitable::ConnectionDetailQuery.new.call(@connection.id)
    assert_equal 1, detail.api_snapshot.mapped_employer_count
    assert_equal 1, detail.api_snapshot.mapped_group_count
    assert_equal 1, detail.api_snapshot.remote_employee_count
    assert_equal 1, detail.api_snapshot.mapped_employee_count
    assert_equal 1, detail.api_snapshot.remote_employee_deduction_changed_count
  ensure
    ENV[@connection.api_key_reference] = previous_key
  end

  test "Vitable API snapshot refresh fails when remote roster employee omits remote id" do
    response_class = Data.define(:data)
    gateway_class = Class.new do
      define_method(:initialize) { |_connection| }
      define_method(:list_all_employers) do
        response_class.new(
          data: [
            {
              id: "empr_ops_123",
              name: "Ops Employer",
              legal_name: "Ops Employer LLC",
              reference_id: "musto_employer_#{Employer.find_by!(name: "Ops Employer").id}",
              active: true
            }
          ]
        )
      end
      define_method(:list_all_groups) { response_class.new(data: []) }
      define_method(:list_all_plans) { response_class.new(data: []) }
      define_method(:list_all_employer_employees) do |_employer_id|
        response_class.new(
          data: [
            {
              member_id: "mem_remote_casey_missing_snapshot_employee_id",
              reference_id: "musto_employee_#{Employee.find_by!(email: "casey@example.com").id}",
              email: "casey@example.com",
              status: "active"
            }
          ]
        )
      end
    end
    previous_key = ENV[@connection.api_key_reference]
    ENV[@connection.api_key_reference] = "vit_apk_test_value"

    result = Vitable::RefreshApiSnapshotCommand.new(
      dto: Vitable::RefreshApiSnapshotDto.new(connection_id: @connection.id, requested_by: "integration_admin"),
      gateway_class:
    ).call

    assert result.failure?
    assert_nil @employee.reload.vitable_id
    assert_nil @employee.metadata.fetch("vitable_member_id", nil)
    assert_nil @connection.reload.metadata.fetch("api_snapshot", nil)
    sync = @connection.sync_runs.where(operation: "api_snapshot_refresh").recent_first.first
    assert_equal "failed", sync.status
    assert_match "remote employee ID", sync.error_message
    assert_match "remote employee ID", result.errors.to_sentence
  ensure
    ENV[@connection.api_key_reference] = previous_key
  end

  test "Vitable API snapshot refresh fails when employer omits remote employer id" do
    response_class = Data.define(:data)
    gateway_class = Class.new do
      define_method(:initialize) { |_connection| }
      define_method(:list_all_employers) do
        response_class.new(
          data: [
            {
              name: "Ops Employer",
              legal_name: "Ops Employer LLC",
              reference_id: "musto_employer_#{Employer.find_by!(name: "Ops Employer").id}",
              active: true
            }
          ]
        )
      end
      define_method(:list_all_groups) { response_class.new(data: []) }
      define_method(:list_all_plans) { response_class.new(data: []) }
    end
    previous_key = ENV[@connection.api_key_reference]
    ENV[@connection.api_key_reference] = "vit_apk_test_value"

    result = Vitable::RefreshApiSnapshotCommand.new(
      dto: Vitable::RefreshApiSnapshotDto.new(connection_id: @connection.id, requested_by: "integration_admin"),
      gateway_class:
    ).call

    assert result.failure?
    assert_nil @employer.reload.vitable_id
    assert_nil @connection.reload.metadata.fetch("api_snapshot", nil)
    sync = @connection.sync_runs.where(operation: "api_snapshot_refresh").recent_first.first
    assert_equal "failed", sync.status
    assert_match "remote employer ID", sync.error_message
    assert_match "remote employer ID", result.errors.to_sentence
  ensure
    ENV[@connection.api_key_reference] = previous_key
  end

  test "Vitable API snapshot refresh fails when group omits remote group id" do
    response_class = Data.define(:data)
    gateway_class = Class.new do
      define_method(:initialize) { |_connection| }
      define_method(:list_all_employers) { response_class.new(data: []) }
      define_method(:list_all_groups) do
        response_class.new(
          data: [
            {
              name: "Ops Employer",
              external_reference_id: "musto_care_group_#{Employer.find_by!(name: "Ops Employer").id}",
              organization_id: "org_demo_vitable"
            }
          ]
        )
      end
      define_method(:list_all_plans) { response_class.new(data: []) }
    end
    previous_key = ENV[@connection.api_key_reference]
    ENV[@connection.api_key_reference] = "vit_apk_test_value"

    result = Vitable::RefreshApiSnapshotCommand.new(
      dto: Vitable::RefreshApiSnapshotDto.new(connection_id: @connection.id, requested_by: "integration_admin"),
      gateway_class:
    ).call

    assert result.failure?
    assert_nil @employer.reload.settings.to_h.fetch("vitable_care_group_id", nil)
    assert_nil @connection.reload.metadata.fetch("api_snapshot", nil)
    sync = @connection.sync_runs.where(operation: "api_snapshot_refresh").recent_first.first
    assert_equal "failed", sync.status
    assert_match "remote group ID", sync.error_message
    assert_match "remote group ID", result.errors.to_sentence
  ensure
    ENV[@connection.api_key_reference] = previous_key
  end

  test "Vitable API snapshot refresh records remote employer id conflicts" do
    @employer.update!(vitable_id: "empr_current_ops")
    response_class = Data.define(:data)
    gateway_class = Class.new do
      define_method(:initialize) { |_connection| }
      define_method(:list_all_employers) do
        response_class.new(
          data: [
            {
              id: "empr_conflicting_ops",
              name: "Ops Employer",
              legal_name: "Ops Employer LLC",
              reference_id: "musto_employer_#{Employer.find_by!(name: "Ops Employer").id}",
              active: true
            }
          ]
        )
      end
      define_method(:list_all_groups) { response_class.new(data: []) }
      define_method(:list_all_plans) { response_class.new(data: []) }
      define_method(:list_all_webhook_events) { |**_filters| response_class.new(data: []) }
      define_method(:list_all_employer_employees) { |_employer_id| response_class.new(data: []) }
      define_method(:list_all_employee_enrollments) { |_employee_id| response_class.new(data: []) }
    end
    previous_key = ENV[@connection.api_key_reference]
    ENV[@connection.api_key_reference] = "vit_apk_test_value"

    result = Vitable::RefreshApiSnapshotCommand.new(
      dto: Vitable::RefreshApiSnapshotDto.new(connection_id: @connection.id, requested_by: "integration_admin"),
      gateway_class:
    ).call

    assert result.success?
    @employer.reload
    snapshot = @connection.reload.metadata.fetch("api_snapshot")
    conflict = @employer.settings.fetch("vitable_remote_employer_conflict")

    assert_equal "empr_current_ops", @employer.vitable_id
    assert_equal 1, snapshot.dig("counts", "conflicting_remote_employer_count")
    assert_equal 0, snapshot.dig("counts", "mapped_employer_count")
    assert_equal "empr_current_ops", conflict.fetch("local_employer_vitable_id")
    assert_equal "empr_conflicting_ops", conflict.fetch("remote_employer_id")
    assert_equal "musto_employer_#{@employer.id}", conflict.fetch("remote_reference_id")
    assert_equal "reference_id", conflict.fetch("matched_by")
    assert_equal "vitable_api_snapshot", conflict.fetch("source")

    reconciliation = Vitable::RemoteEmployerSnapshotRepository.new(connection: @connection).reconcile_snapshot(
      remote_employers: [
        {
          id: "empr_current_ops",
          name: "Ops Employer",
          legal_name: "Ops Employer LLC",
          reference_id: "musto_employer_#{@employer.id}",
          active: true
        }
      ],
      source: "vitable_api_snapshot",
      refreshed_at: Time.current.iso8601
    )

    assert_equal 1, reconciliation.matched_count
    assert_nil @employer.reload.settings.to_h.fetch("vitable_remote_employer_conflict", nil)
  ensure
    ENV[@connection.api_key_reference] = previous_key
  end

  test "vitable employer provisioning workspace exposes packet DTOs" do
    prepare_provisioning_profile
    Vitable::GenerateEmployerProvisioningCommand.new(dto: Vitable::GenerateEmployerProvisioningDto.new(requested_by: "ops_test")).call
    detail = Vitable::EmployerProvisioningQuery.new.call

    assert_instance_of Vitable::EmployerProvisioningCenterDto, detail
    assert_instance_of Vitable::EmployerProvisioningMetricDto, detail.metrics.first
    assert_instance_of Vitable::EmployerProvisioningPreflightCheckDto, detail.preflight_checks.first
    assert_instance_of Vitable::EmployerProvisioningPacketDto, detail.latest_packet
    assert_instance_of Vitable::EmployerProvisioningPayloadDto, detail.payload
    assert_empty detail.holdbacks
    assert_equal "create", detail.latest_packet.mode
    assert_equal "bi_weekly", detail.payload.pay_frequency
    assert_equal "All", detail.payload.eligibility_classification
    assert_equal "1st of the following month", detail.payload.eligibility_waiting_period

    get vitable_employer_provisioning_path

    assert_response :success
    assert_select "h1", "Vitable employer provisioning"
    assert_select "h2", "Provisioning preflight"
    assert_select "h2", "Submission field review"
    assert_select "h2", "Provisioning holdbacks"
    assert_select "h2", "Provisioning attempts"
    assert_select "h2", "Employer submission activity"
  end

  test "generates a Vitable employer provisioning packet" do
    prepare_provisioning_profile

    post generate_vitable_employer_provisioning_path, params: { requested_by: "integration_admin" }

    assert_redirected_to vitable_employer_provisioning_path
    packet = @employer.reload.settings.fetch("vitable_employer_provisioning_packet")
    assert_match(/\Avitable_employer_provisioning_#{@employer.id}_/, packet.fetch("packet_id"))
    assert_equal "integration_admin", packet.fetch("requested_by")
    assert_equal "create", packet.fetch("mode")
    assert_equal "ready", packet.fetch("status")
    assert_equal "/v1/employers", packet.fetch("endpoint")
    assert_equal "ops-benefits@example.com", packet.fetch("create_payload").fetch("email")
    assert_equal "214 Market Street", packet.fetch("create_payload").fetch("address").fetch("address_line_1")
    assert_equal "bi_weekly", packet.fetch("settings_payload").fetch("pay_frequency")
    assert_equal "All", packet.fetch("eligibility_policy_payload").fetch("classification")
    assert_equal "1st of the following month", packet.fetch("eligibility_policy_payload").fetch("waiting_period")
    assert_equal "submit", packet.fetch("eligibility_policy_action")
    assert_equal "/v1/employers/:employer_id/benefit-eligibility-policies", packet.fetch("eligibility_policy_endpoint")
    assert_equal [
      "/v1/employers",
      "/v1/employers/:employer_id/settings",
      "/v1/employers/:employer_id/benefit-eligibility-policies"
    ], packet.fetch("endpoint_sequence")
    assert_empty packet.fetch("holdbacks")
  end

  test "Vitable employer provisioning normalizes outbound create fields" do
    prepare_provisioning_profile
    @employer.update!(
      ein: "123456789",
      settings: @employer.settings.to_h.merge(
        "billing_email" => " OPS-BENEFITS@EXAMPLE.COM ",
        "phone_number" => "+1 (555) 123-9000"
      )
    )
    @employer.work_locations.find_by!(name: "Ops HQ").update!(
      state: "pa",
      postal_code: " 19106-1234 "
    )

    post generate_vitable_employer_provisioning_path, params: { requested_by: "integration_admin" }

    packet = @employer.reload.settings.fetch("vitable_employer_provisioning_packet")
    payload = packet.fetch("create_payload")

    assert_equal "ready", packet.fetch("status")
    assert_equal "12-3456789", payload.fetch("ein")
    assert_equal "ops-benefits@example.com", payload.fetch("email")
    assert_equal "5551239000", payload.fetch("phone_number")
    assert_equal "PA", payload.fetch("address").fetch("state")
    assert_equal "19106-1234", payload.fetch("address").fetch("zipcode")
    assert_empty packet.fetch("holdbacks")
  end

  test "Vitable employer provisioning blocks invalid API contract fields" do
    prepare_provisioning_profile
    @employer.update!(
      ein: "12345",
      settings: @employer.settings.to_h.merge(
        "billing_email" => "ops-benefits",
        "phone_number" => "555123",
        "pay_frequency" => "annually"
      )
    )
    @employer.work_locations.find_by!(name: "Ops HQ").update!(
      state: "Pennsylvania",
      postal_code: "191"
    )

    post generate_vitable_employer_provisioning_path, params: { requested_by: "integration_admin" }

    packet = @employer.reload.settings.fetch("vitable_employer_provisioning_packet")
    reason_codes = packet.fetch("holdbacks").map { |holdback| holdback.fetch("reason_code") }

    assert_equal "blocked", packet.fetch("status")
    assert_includes reason_codes, "invalid_ein_format"
    assert_includes reason_codes, "invalid_billing_email"
    assert_includes reason_codes, "invalid_phone_number"
    assert_includes reason_codes, "invalid_state_code"
    assert_includes reason_codes, "invalid_zipcode"
    assert_includes reason_codes, "unsupported_pay_frequency"

    detail = Vitable::EmployerProvisioningQuery.new.call
    assert_equal "blocked", detail.preflight_checks.find { |check| check.label == "Legal entity" }.status
    assert_equal "blocked", detail.preflight_checks.find { |check| check.label == "Physical address" }.status
    assert_equal "blocked", detail.metrics.find { |metric| metric.label == "Pay frequency" }.status
  end

  test "submits Vitable employer provisioning as missing credentials sync run without API key" do
    prepare_provisioning_profile
    Vitable::GenerateEmployerProvisioningCommand.new(dto: Vitable::GenerateEmployerProvisioningDto.new(requested_by: "ops_test")).call

    assert_difference -> { @connection.sync_runs.where(operation: "employer_create").count }, 1 do
      post submit_vitable_employer_provisioning_path, params: { requested_by: "integration_admin" }
    end

    assert_redirected_to vitable_employer_provisioning_path
    sync = @connection.sync_runs.where(operation: "employer_create").recent_first.first
    assert_equal "needs_credentials", sync.status
    assert_match @connection.api_key_reference, sync.error_message
    assert_equal "integration_admin", sync.stats.fetch("requested_by")
    assert_equal "ops-benefits@example.com", sync.stats.dig("payload", "create", "email")
    assert_equal "All", sync.stats.dig("payload", "eligibility_policy", "classification")
  end

  test "successful employer provisioning command stores remote id and remote eligibility policy" do
    prepare_provisioning_profile
    response_class = Data.define(:data)
    gateway_class = Class.new do
      define_method(:initialize) { |_connection| }
      define_method(:create_employer) do |payload|
        response_class.new(
          data: {
            id: "empr_created_123",
            name: payload.fetch("name"),
            reference_id: payload.fetch("reference_id"),
            access_token: "vit_at_employer_snapshot_secret"
          }
        )
      end
      define_method(:update_employer_settings) do |employer_id, pay_frequency|
        response_class.new(data: { employer_id:, pay_frequency:, client_secret: "vit_client_secret_snapshot" })
      end
      define_method(:create_eligibility_policy) do |employer_id, payload|
        response_class.new(
          data: {
            id: "elig_policy_123",
            employer_id:,
            classification: payload.fetch("classification"),
            waiting_period: payload.fetch("waiting_period"),
            refresh_token: "vit_rt_policy_snapshot_secret"
          }
        )
      end
    end
    previous_key = ENV[@connection.api_key_reference]
    ENV[@connection.api_key_reference] = "vit_apk_test_value"

    result = Vitable::SubmitEmployerProvisioningCommand.new(
      dto: Vitable::SubmitEmployerProvisioningDto.new(requested_by: "integration_admin"),
      gateway_class:
    ).call

    assert result.success?
    assert_equal "empr_created_123", @employer.reload.vitable_id
    assert_equal "bi_weekly", @employer.settings.fetch("vitable_pay_frequency")
    assert_equal "remote_api", @employer.settings.dig("vitable_eligibility_policy", "source")
    assert_equal "remote_submitted", @employer.settings.dig("vitable_eligibility_policy", "status")
    assert_equal "All", @employer.settings.dig("vitable_eligibility_policy", "classification")
    assert_equal "elig_policy_123", @employer.settings.dig("vitable_eligibility_policy", "remote_response", "data", "id")
    sync = @connection.sync_runs.where(operation: "employer_create").recent_first.first
    assert_equal "succeeded", sync.status
    assert_equal "empr_created_123", sync.stats.fetch("remote_employer_id")
    assert_equal "bi_weekly", sync.stats.dig("remote_response", "settings_response", "data", "pay_frequency")
    assert_equal "remote_submitted", sync.stats.dig("remote_response", "eligibility_policy_submission", "status")
    assert_equal "elig_policy_123", sync.stats.dig("remote_response", "eligibility_policy_submission", "remote_response", "data", "id")
    assert_equal "[FILTERED]", sync.stats.dig("remote_response", "employer_response", "data", "access_token")
    assert_equal "[FILTERED]", sync.stats.dig("remote_response", "settings_response", "data", "client_secret")
    assert_equal "[FILTERED]", sync.stats.dig("remote_response", "eligibility_policy_submission", "remote_response", "data", "refresh_token")
    assert_not_includes sync.stats.to_json, "vit_at_employer_snapshot_secret"
    assert_not_includes sync.stats.to_json, "vit_client_secret_snapshot"
    assert_not_includes @employer.settings.to_json, "vit_rt_policy_snapshot_secret"
  ensure
    ENV[@connection.api_key_reference] = previous_key
  end

  test "employer provisioning fails before dependent calls when create omits remote id" do
    prepare_provisioning_profile
    response_class = Data.define(:data)
    gateway_class = Class.new do
      define_method(:initialize) { |_connection| }
      define_method(:create_employer) { |payload| response_class.new(data: { name: payload.fetch("name") }) }
      define_method(:update_employer_settings) { |_employer_id, _pay_frequency| raise "settings should not be called without remote employer ID" }
      define_method(:create_eligibility_policy) { |_employer_id, _payload| raise "policy should not be called without remote employer ID" }
    end
    previous_key = ENV[@connection.api_key_reference]
    ENV[@connection.api_key_reference] = "vit_apk_test_value"

    result = Vitable::SubmitEmployerProvisioningCommand.new(
      dto: Vitable::SubmitEmployerProvisioningDto.new(requested_by: "integration_admin"),
      gateway_class:
    ).call

    assert result.failure?
    assert_nil @employer.reload.vitable_id
    sync = @connection.sync_runs.where(operation: "employer_create").recent_first.first
    assert_equal "failed", sync.status
    assert_match "remote employer ID", sync.error_message
    assert_match "remote employer ID", result.errors.to_sentence
  ensure
    ENV[@connection.api_key_reference] = previous_key
  end

  test "employer provisioning fails before dependent calls when create response reference differs from packet" do
    prepare_provisioning_profile
    response_class = Data.define(:data)
    gateway_class = Class.new do
      define_method(:initialize) { |_connection| }
      define_method(:create_employer) do |payload|
        response_class.new(
          data: {
            id: "empr_created_wrong_reference",
            name: payload.fetch("name"),
            reference_id: "musto_employer_wrong"
          }
        )
      end
      define_method(:update_employer_settings) { |_employer_id, _pay_frequency| raise "settings should not be called with mismatched employer reference" }
      define_method(:create_eligibility_policy) { |_employer_id, _payload| raise "policy should not be called with mismatched employer reference" }
    end
    previous_key = ENV[@connection.api_key_reference]
    ENV[@connection.api_key_reference] = "vit_apk_test_value"

    result = Vitable::SubmitEmployerProvisioningCommand.new(
      dto: Vitable::SubmitEmployerProvisioningDto.new(requested_by: "integration_admin"),
      gateway_class:
    ).call

    assert result.failure?
    assert_nil @employer.reload.vitable_id
    sync = @connection.sync_runs.where(operation: "employer_create").recent_first.first
    assert_equal "failed", sync.status
    assert_match "expected musto_employer_#{@employer.id}", sync.error_message
    assert_match "expected musto_employer_#{@employer.id}", result.errors.to_sentence
  ensure
    ENV[@connection.api_key_reference] = previous_key
  end

  test "successful employer settings command stores pay frequency metadata" do
    prepare_provisioning_profile(remote_id: "empr_ops_123")
    response_class = Data.define(:data)
    gateway_class = Class.new do
      define_method(:initialize) { |_connection| }
      define_method(:update_employer_settings) do |employer_id, pay_frequency|
        response_class.new(data: { employer_id:, pay_frequency: })
      end
      define_method(:create_eligibility_policy) do |employer_id, payload|
        response_class.new(data: { id: "elig_policy_update_123", employer_id:, classification: payload.fetch("classification") })
      end
    end
    previous_key = ENV[@connection.api_key_reference]
    ENV[@connection.api_key_reference] = "vit_apk_test_value"

    result = Vitable::SubmitEmployerProvisioningCommand.new(
      dto: Vitable::SubmitEmployerProvisioningDto.new(requested_by: "integration_admin"),
      gateway_class:
    ).call

    assert result.success?
    assert_equal "empr_ops_123", @employer.reload.vitable_id
    assert_equal "bi_weekly", @employer.settings.fetch("vitable_pay_frequency")
    sync = @connection.sync_runs.where(operation: "employer_settings_update").recent_first.first
    assert_equal "succeeded", sync.status
    assert_equal "bi_weekly", sync.stats.dig("payload", "settings", "pay_frequency")
    assert_equal "remote_submitted", sync.stats.dig("remote_response", "eligibility_policy_submission", "status")
    assert_equal "remote_api", @employer.settings.dig("vitable_eligibility_policy", "source")
  ensure
    ENV[@connection.api_key_reference] = previous_key
  end

  test "employer settings command fails when response pay frequency differs from requested value" do
    prepare_provisioning_profile(remote_id: "empr_ops_123")
    response_class = Data.define(:data)
    gateway_class = Class.new do
      define_method(:initialize) { |_connection| }
      define_method(:update_employer_settings) do |employer_id, _pay_frequency|
        response_class.new(data: { employer_id:, pay_frequency: "monthly" })
      end
      define_method(:create_eligibility_policy) { |_employer_id, _payload| raise "policy should not be called with mismatched settings response" }
    end
    previous_key = ENV[@connection.api_key_reference]
    ENV[@connection.api_key_reference] = "vit_apk_test_value"

    result = Vitable::SubmitEmployerProvisioningCommand.new(
      dto: Vitable::SubmitEmployerProvisioningDto.new(requested_by: "integration_admin"),
      gateway_class:
    ).call

    assert result.failure?
    assert_equal "empr_ops_123", @employer.reload.vitable_id
    assert_nil @employer.settings.to_h.fetch("vitable_pay_frequency", nil)
    sync = @connection.sync_runs.where(operation: "employer_settings_update").recent_first.first
    assert_equal "failed", sync.status
    assert_match "expected bi_weekly", sync.error_message
    assert_match "expected bi_weekly", result.errors.to_sentence
  ensure
    ENV[@connection.api_key_reference] = previous_key
  end

  test "employer provisioning fails when eligibility policy response omits remote policy id" do
    prepare_provisioning_profile(remote_id: "empr_ops_123")
    response_class = Data.define(:data)
    gateway_class = Class.new do
      define_method(:initialize) { |_connection| }
      define_method(:update_employer_settings) do |employer_id, pay_frequency|
        response_class.new(data: { employer_id:, pay_frequency: })
      end
      define_method(:create_eligibility_policy) do |employer_id, payload|
        response_class.new(data: { employer_id:, classification: payload.fetch("classification") })
      end
    end
    previous_key = ENV[@connection.api_key_reference]
    ENV[@connection.api_key_reference] = "vit_apk_test_value"

    result = Vitable::SubmitEmployerProvisioningCommand.new(
      dto: Vitable::SubmitEmployerProvisioningDto.new(requested_by: "integration_admin"),
      gateway_class:
    ).call

    assert result.failure?
    assert_nil @employer.reload.settings.to_h.fetch("vitable_eligibility_policy", nil)
    sync = @connection.sync_runs.where(operation: "employer_settings_update").recent_first.first
    assert_equal "failed", sync.status
    assert_match "remote policy ID", sync.error_message
    assert_match "remote policy ID", result.errors.to_sentence
  ensure
    ENV[@connection.api_key_reference] = previous_key
  end

  test "employer provisioning fails when eligibility policy response employer differs from submitted employer" do
    prepare_provisioning_profile(remote_id: "empr_ops_123")
    response_class = Data.define(:data)
    gateway_class = Class.new do
      define_method(:initialize) { |_connection| }
      define_method(:update_employer_settings) do |employer_id, pay_frequency|
        response_class.new(data: { employer_id:, pay_frequency: })
      end
      define_method(:create_eligibility_policy) do |_employer_id, payload|
        response_class.new(data: { id: "elig_policy_123", employer_id: "empr_other_456", classification: payload.fetch("classification") })
      end
    end
    previous_key = ENV[@connection.api_key_reference]
    ENV[@connection.api_key_reference] = "vit_apk_test_value"

    result = Vitable::SubmitEmployerProvisioningCommand.new(
      dto: Vitable::SubmitEmployerProvisioningDto.new(requested_by: "integration_admin"),
      gateway_class:
    ).call

    assert result.failure?
    assert_nil @employer.reload.settings.to_h.fetch("vitable_eligibility_policy", nil)
    sync = @connection.sync_runs.where(operation: "employer_settings_update").recent_first.first
    assert_equal "failed", sync.status
    assert_match "expected empr_ops_123", sync.error_message
    assert_match "expected empr_ops_123", result.errors.to_sentence
  ensure
    ENV[@connection.api_key_reference] = previous_key
  end

  test "employer provisioning records existing remote eligibility policy on duplicate policy response" do
    prepare_provisioning_profile(remote_id: "empr_ops_123")
    response_class = Data.define(:data)
    gateway_class = Class.new do
      define_method(:initialize) { |_connection| }
      define_method(:update_employer_settings) do |employer_id, pay_frequency|
        response_class.new(data: { employer_id:, pay_frequency: })
      end
      define_method(:create_eligibility_policy) do |_employer_id, _payload|
        raise VitableConnect::Errors::APIStatusError.new(
          url: URI("https://api.demo.vitablehealth.com/v1/employers/empr_ops_123/benefit-eligibility-policies"),
          status: 422,
          headers: {},
          body: { error: "active policy already exists" },
          request: nil,
          response: nil
        )
      end
    end
    previous_key = ENV[@connection.api_key_reference]
    ENV[@connection.api_key_reference] = "vit_apk_test_value"

    result = Vitable::SubmitEmployerProvisioningCommand.new(
      dto: Vitable::SubmitEmployerProvisioningDto.new(requested_by: "integration_admin"),
      gateway_class:
    ).call

    assert result.success?
    sync = @connection.sync_runs.where(operation: "employer_settings_update").recent_first.first
    assert_equal "succeeded", sync.status
    assert_equal "remote_existing", sync.stats.dig("remote_response", "eligibility_policy_submission", "status")
    assert_equal "remote_existing", @employer.reload.settings.dig("vitable_eligibility_policy", "source")
  ensure
    ENV[@connection.api_key_reference] = previous_key
  end

  test "vitable census sync workspace exposes manifest DTOs" do
    holdback_employee = create_census_holdback_employee
    Vitable::GenerateCensusManifestCommand.new(dto: Vitable::GenerateCensusManifestDto.new(requested_by: "ops_test")).call
    detail = Vitable::CensusSyncQuery.new.call

    assert_instance_of Vitable::CensusSyncCenterDto, detail
    assert_instance_of Vitable::CensusSyncMetricDto, detail.metrics.first
    assert_instance_of Vitable::CensusSyncPreflightCheckDto, detail.preflight_checks.first
    assert_instance_of Vitable::CensusSyncManifestDto, detail.latest_manifest
    assert_instance_of Vitable::CensusSyncEmployeeDto, detail.employees.first
    assert_instance_of Vitable::CensusSyncHoldbackDto, detail.holdbacks.first
    assert_nil detail.latest_submission
    assert_nil detail.latest_verification
    assert_equal @employee.id, detail.employees.first.employee_id
    assert_equal holdback_employee.id, detail.holdbacks.first.employee_id

    get vitable_census_sync_path

    assert_response :success
    assert_select "h1", "Vitable census sync"
    assert_select "h2", "Submit preflight"
    assert_select "h2", "Ready census rows"
    assert_select "h2", "Offboarding omissions"
    assert_select "h2", "Holdbacks"
    assert_select "h2", "Sync attempts"
    assert_select "h2", "Submission activity"
    assert_select "button", "Refresh remote roster"
  end

  test "generates a Vitable census manifest through command action" do
    create_census_holdback_employee

    post generate_vitable_census_manifest_path, params: { requested_by: "integration_admin" }

    assert_redirected_to vitable_census_sync_path
    batch = @employer.reload.settings.fetch("vitable_census_sync_batch")
    assert_match(/\Avitable_census_#{@employer.id}_/, batch.fetch("batch_id"))
    assert_equal "integration_admin", batch.fetch("requested_by")
    assert_equal "needs_review", batch.fetch("status")
    assert_equal 2, batch.fetch("totals").fetch("employee_count")
    assert_equal 1, batch.fetch("totals").fetch("ready_count")
    assert_equal 1, batch.fetch("totals").fetch("holdback_count")
    assert_equal "5551234567", batch.fetch("employees").first.fetch("phone")
    assert_equal "missing_required_fields", batch.fetch("holdbacks").first.fetch("reason_code")
    assert_equal "/v1/employers/:employer_id/census-sync", batch.fetch("endpoint")
  end

  test "Vitable census manifest normalizes employee API fields" do
    prepare_provisioning_profile(remote_id: "empr_ops_123")
    location = @employer.work_locations.find_by!(name: "Ops HQ")
    location.update!(state: "pa", postal_code: " 19106-1234 ")
    @employee.update!(
      email: " CASEY@EXAMPLE.COM ",
      work_location: location,
      metadata: @employee.metadata.to_h.merge("phone" => "+1 (555) 123-4567")
    )

    post generate_vitable_census_manifest_path, params: { requested_by: "integration_admin" }

    batch = @employer.reload.settings.fetch("vitable_census_sync_batch")
    employee_payload = batch.fetch("api_payload").fetch("employees").first

    assert_equal "ready", batch.fetch("status")
    assert_equal "casey@example.com", employee_payload.fetch("email")
    assert_equal "5551234567", employee_payload.fetch("phone")
    assert_equal "PA", employee_payload.fetch("address").fetch("state")
    assert_equal "19106-1234", employee_payload.fetch("address").fetch("zipcode")
    assert_empty batch.fetch("holdbacks")
  end

  test "Vitable census manifest holds back invalid employee API fields" do
    prepare_provisioning_profile(remote_id: "empr_ops_123")
    location = @employer.work_locations.find_by!(name: "Ops HQ")
    location.update!(state: "Pennsylvania", postal_code: "191")
    @employee.update!(
      email: "casey",
      work_location: location,
      metadata: @employee.metadata.to_h.merge("phone" => "555123")
    )

    post generate_vitable_census_manifest_path, params: { requested_by: "integration_admin" }

    batch = @employer.reload.settings.fetch("vitable_census_sync_batch")
    holdback = batch.fetch("holdbacks").first

    assert_equal "blocked", batch.fetch("status")
    assert_equal 0, batch.fetch("totals").fetch("ready_count")
    assert_equal "invalid_api_contract_fields", holdback.fetch("reason_code")
    assert_includes holdback.fetch("reason"), "email"
    assert_includes holdback.fetch("reason"), "phone"
    assert_includes holdback.fetch("reason"), "address state"
    assert_includes holdback.fetch("reason"), "address ZIP"
    assert_empty batch.fetch("api_payload").fetch("employees")
  end

  test "census manifest omits approved offboarding employees for Vitable deactivation" do
    @employer.update!(vitable_id: "empr_ops_123")
    @employee.update!(vitable_id: "empl_ops_casey")
    @enrollment.update!(vitable_id: "enrl_ops_primary")
    @dependent.update!(vitable_id: "dep_ops_harper")
    Benefits::GenerateOffboardingPacketCommand.new(dto: Benefits::GenerateOffboardingPacketDto.new(requested_by: "benefits_admin")).call

    post generate_vitable_census_manifest_path, params: { requested_by: "integration_admin" }

    assert_redirected_to vitable_census_sync_path
    batch = @employer.reload.settings.fetch("vitable_census_sync_batch")
    assert_equal "blocked", batch.fetch("status")
    assert_equal 1, batch.fetch("totals").fetch("offboarding_omission_count")
    assert_empty batch.fetch("api_payload").fetch("employees")
    omission = batch.fetch("offboarding_omissions").first
    assert_equal @employee.id, omission.fetch("employee_id")
    assert_equal "musto_employee_#{@employee.id}", omission.fetch("reference_id")
    assert_equal "empl_ops_casey", omission.fetch("remote_employee_id")

    detail = Vitable::CensusSyncQuery.new.call
    assert_not detail.submittable?
    assert_instance_of Vitable::CensusSyncOffboardingOmissionDto, detail.offboarding_omissions.first
    assert_equal "blocked", detail.preflight_checks.find { |check| check.label == "Batch size" }.status
  end

  test "blocks offboarding-only Vitable census sync before remote submit" do
    @employer.update!(vitable_id: "empr_ops_123")
    @employee.update!(vitable_id: "empl_ops_casey")
    @enrollment.update!(vitable_id: "enrl_ops_primary")
    @dependent.update!(vitable_id: "dep_ops_harper")
    Benefits::GenerateOffboardingPacketCommand.new(dto: Benefits::GenerateOffboardingPacketDto.new(requested_by: "benefits_admin")).call
    Vitable::GenerateCensusManifestCommand.new(dto: Vitable::GenerateCensusManifestDto.new(requested_by: "ops_test")).call

    response_class = Data.define(:data)
    gateway_class = Class.new do
      define_method(:initialize) { |_connection| raise "gateway should not be called for empty census roster" }
      define_method(:submit_census_sync) do |employer_id, employees|
        response_class.new(
          data: {
            employer_id:,
            accepted_at: Time.current,
            employee_count: employees.count,
            access_token: "vit_at_census_snapshot_secret"
          }
        )
      end
    end
    previous_key = ENV[@connection.api_key_reference]
    ENV[@connection.api_key_reference] = "vit_apk_test_value"

    result = Vitable::SubmitCensusSyncCommand.new(
      dto: Vitable::SubmitCensusSyncDto.new(requested_by: "integration_admin"),
      gateway_class:
    ).call

    assert_not result.success?
    assert_nil @employer.reload.settings.fetch("vitable_census_sync_last_submission", nil)
    sync = @connection.sync_runs.where(operation: "census_sync").recent_first.first
    assert_equal "blocked", sync.status
    assert_equal "Generate at least one ready employee row before submitting census sync", sync.error_message
    assert_equal "Generate at least one ready employee row before submitting census sync", sync.stats.fetch("blocked_reason")
    assert_nil @employee.reload.metadata.fetch("vitable_census_sync_status", nil)
    omission = @employer.settings.fetch("vitable_census_sync_batch").fetch("offboarding_omissions").first
    assert_nil omission.fetch("submitted_at", nil)
    assert_nil omission.fetch("accepted_at", nil)
  ensure
    ENV[@connection.api_key_reference] = previous_key
  end

  test "submits Vitable census sync as missing credentials sync run without API key" do
    @employer.update!(vitable_id: "empr_ops_123")
    Vitable::GenerateCensusManifestCommand.new(dto: Vitable::GenerateCensusManifestDto.new(requested_by: "ops_test")).call

    assert_difference -> { @connection.sync_runs.where(operation: "census_sync").count }, 1 do
      post submit_vitable_census_sync_path, params: { requested_by: "integration_admin" }
    end

    assert_redirected_to vitable_census_sync_path
    sync = @connection.sync_runs.where(operation: "census_sync").recent_first.first
    assert_equal "needs_credentials", sync.status
    assert_match @connection.api_key_reference, sync.error_message
    assert_equal "integration_admin", sync.stats.fetch("requested_by")
    assert_equal @employee.email, sync.stats.fetch("payload").fetch("employees").first.fetch("email")
  end

  test "successful Vitable census sync stores accepted submission state" do
    @employer.update!(vitable_id: "empr_ops_123")
    Vitable::GenerateCensusManifestCommand.new(dto: Vitable::GenerateCensusManifestDto.new(requested_by: "ops_test")).call
    response_class = Data.define(:data)
    gateway_class = Class.new do
      define_method(:initialize) { |_connection| }
      define_method(:submit_census_sync) do |employer_id, employees|
        response_class.new(
          data: {
            employer_id:,
            accepted_at: Time.current,
            employee_count: employees.count,
            access_token: "vit_at_census_snapshot_secret"
          }
        )
      end
    end
    previous_key = ENV[@connection.api_key_reference]
    ENV[@connection.api_key_reference] = "vit_apk_test_value"

    result = Vitable::SubmitCensusSyncCommand.new(
      dto: Vitable::SubmitCensusSyncDto.new(requested_by: "integration_admin"),
      gateway_class:
    ).call

    assert result.success?
    submission = @employer.reload.settings.fetch("vitable_census_sync_last_submission")
    assert_equal "accepted", submission.fetch("status")
    assert_equal "empr_ops_123", submission.fetch("remote_employer_id")
    assert_equal 1, submission.fetch("ready_count")
    assert_equal [ "musto_employee_#{@employee.id}" ], submission.fetch("employee_reference_ids")
    manifest_line = @employer.settings.fetch("vitable_census_sync_batch").fetch("employees").first
    assert_equal "submitted", manifest_line.fetch("status")
    assert_equal "submitted", @employee.reload.metadata.fetch("vitable_census_sync_status")
    assert_equal submission.fetch("batch_id"), @employee.metadata.fetch("vitable_census_sync_batch_id")

    detail = Vitable::CensusSyncQuery.new.call
    assert_instance_of Vitable::CensusSyncSubmissionDto, detail.latest_submission
    assert_equal "accepted", detail.latest_submission.status
    sync = @connection.sync_runs.where(operation: "census_sync").recent_first.first
    assert_equal "[FILTERED]", sync.stats.dig("remote_response", "data", "access_token")
    assert_not_includes sync.stats.to_json, "vit_at_census_snapshot_secret"
  ensure
    ENV[@connection.api_key_reference] = previous_key
  end

  test "Vitable census sync fails when response omits accepted timestamp" do
    @employer.update!(vitable_id: "empr_ops_123")
    Vitable::GenerateCensusManifestCommand.new(dto: Vitable::GenerateCensusManifestDto.new(requested_by: "ops_test")).call
    response_class = Data.define(:data)
    gateway_class = Class.new do
      define_method(:initialize) { |_connection| }
      define_method(:submit_census_sync) do |employer_id, employees|
        response_class.new(data: { employer_id:, employee_count: employees.count })
      end
    end
    previous_key = ENV[@connection.api_key_reference]
    ENV[@connection.api_key_reference] = "vit_apk_test_value"

    result = Vitable::SubmitCensusSyncCommand.new(
      dto: Vitable::SubmitCensusSyncDto.new(requested_by: "integration_admin"),
      gateway_class:
    ).call

    assert result.failure?
    assert_nil @employer.reload.settings.to_h.fetch("vitable_census_sync_last_submission", nil)
    manifest_line = @employer.settings.fetch("vitable_census_sync_batch").fetch("employees").first
    assert_not_equal "submitted", manifest_line.fetch("status")
    assert_nil @employee.reload.metadata.fetch("vitable_census_sync_status", nil)
    sync = @connection.sync_runs.where(operation: "census_sync").recent_first.first
    assert_equal "failed", sync.status
    assert_match "accepted_at", sync.error_message
    assert_match "accepted_at", result.errors.to_sentence
  ensure
    ENV[@connection.api_key_reference] = previous_key
  end

  test "Vitable census sync fails when response omits remote employer id" do
    @employer.update!(vitable_id: "empr_ops_123")
    Vitable::GenerateCensusManifestCommand.new(dto: Vitable::GenerateCensusManifestDto.new(requested_by: "ops_test")).call
    response_class = Data.define(:data)
    gateway_class = Class.new do
      define_method(:initialize) { |_connection| }
      define_method(:submit_census_sync) do |_employer_id, employees|
        response_class.new(data: { accepted_at: Time.current, employee_count: employees.count })
      end
    end
    previous_key = ENV[@connection.api_key_reference]
    ENV[@connection.api_key_reference] = "vit_apk_test_value"

    result = Vitable::SubmitCensusSyncCommand.new(
      dto: Vitable::SubmitCensusSyncDto.new(requested_by: "integration_admin"),
      gateway_class:
    ).call

    assert result.failure?
    assert_nil @employer.reload.settings.to_h.fetch("vitable_census_sync_last_submission", nil)
    manifest_line = @employer.settings.fetch("vitable_census_sync_batch").fetch("employees").first
    assert_not_equal "submitted", manifest_line.fetch("status")
    assert_nil @employee.reload.metadata.fetch("vitable_census_sync_status", nil)
    sync = @connection.sync_runs.where(operation: "census_sync").recent_first.first
    assert_equal "failed", sync.status
    assert_match "remote employer ID", sync.error_message
    assert_match "remote employer ID", result.errors.to_sentence
  ensure
    ENV[@connection.api_key_reference] = previous_key
  end

  test "Vitable census sync fails when response employer differs from submitted employer" do
    @employer.update!(vitable_id: "empr_ops_123")
    Vitable::GenerateCensusManifestCommand.new(dto: Vitable::GenerateCensusManifestDto.new(requested_by: "ops_test")).call
    response_class = Data.define(:data)
    gateway_class = Class.new do
      define_method(:initialize) { |_connection| }
      define_method(:submit_census_sync) do |_employer_id, employees|
        response_class.new(
          data: {
            employer_id: "empr_ops_wrong",
            accepted_at: Time.current,
            employee_count: employees.count,
            refresh_token: "vit_rt_wrong_census_response"
          }
        )
      end
    end
    previous_key = ENV[@connection.api_key_reference]
    ENV[@connection.api_key_reference] = "vit_apk_test_value"

    result = Vitable::SubmitCensusSyncCommand.new(
      dto: Vitable::SubmitCensusSyncDto.new(requested_by: "integration_admin"),
      gateway_class:
    ).call

    assert result.failure?
    assert_nil @employer.reload.settings.to_h.fetch("vitable_census_sync_last_submission", nil)
    manifest_line = @employer.settings.fetch("vitable_census_sync_batch").fetch("employees").first
    assert_not_equal "submitted", manifest_line.fetch("status")
    assert_nil @employee.reload.metadata.fetch("vitable_census_sync_status", nil)
    sync = @connection.sync_runs.where(operation: "census_sync").recent_first.first
    assert_equal "failed", sync.status
    assert_match "expected empr_ops_123", sync.error_message
    assert_equal "ArgumentError", sync.stats.fetch("error_class")
    assert_equal "empr_ops_wrong", sync.stats.dig("remote_response", "data", "employer_id")
    assert_equal "[FILTERED]", sync.stats.dig("remote_response", "data", "refresh_token")
    assert_match "expected empr_ops_123", result.errors.to_sentence
    assert_not_includes sync.stats.to_json, "vit_rt_wrong_census_response"
  ensure
    ENV[@connection.api_key_reference] = previous_key
  end

  test "Vitable API snapshot refresh deactivates local benefits for inactive remote employees" do
    deduction = @payroll_run.payroll_deductions.find_by!(enrollment: @enrollment)
    response_class = Data.define(:data)
    gateway_class = Class.new do
      define_method(:initialize) { |_connection| }
      define_method(:list_all_employers) do
        response_class.new(
          data: [
            {
              id: "empr_ops_inactive",
              name: "Ops Employer",
              reference_id: "musto_employer_#{Employer.find_by!(name: "Ops Employer").id}"
            }
          ]
        )
      end
      define_method(:list_all_groups) { response_class.new(data: []) }
      define_method(:list_all_plans) { response_class.new(data: []) }
      define_method(:list_all_webhook_events) { |**_filters| response_class.new(data: []) }
      define_method(:list_all_employer_employees) do |employer_id|
        response_class.new(
          data: [
            {
              id: "empl_remote_inactive_casey",
              member_id: "mem_remote_inactive_casey",
              employer_id:,
              reference_id: "musto_employee_#{Employee.find_by!(email: "casey@example.com").id}",
              email: "casey@example.com",
              status: "inactive"
            }
          ]
        )
      end
      define_method(:list_all_employee_enrollments) { |_employee_id| response_class.new(data: []) }
    end
    previous_key = ENV[@connection.api_key_reference]
    ENV[@connection.api_key_reference] = "vit_apk_test_value"

    result = Vitable::RefreshApiSnapshotCommand.new(
      dto: Vitable::RefreshApiSnapshotDto.new(connection_id: @connection.id, requested_by: "integration_admin"),
      gateway_class:
    ).call

    assert result.success?
    snapshot = @connection.reload.metadata.fetch("api_snapshot")

    assert_equal "terminated", @employee.reload.employment_status
    assert_equal "inactive", @enrollment.reload.status
    assert_nil @enrollment.accepted_at
    assert_equal "inactive", @enrollment.metadata.fetch("vitable_lifecycle_status")
    assert_equal 0, deduction.reload.amount_cents
    assert_equal "inactive", deduction.status
    assert_equal "vitable_api_snapshot", deduction.metadata.fetch("source")
    assert_equal 3, snapshot.dig("counts", "inactive_employee_enrollment_count")
    assert_equal 3, snapshot.dig("counts", "inactive_employee_payroll_deduction_count")

    detail = Vitable::ConnectionDetailQuery.new.call(@connection.id)
    assert_equal 3, detail.api_snapshot.inactive_employee_enrollment_count
    assert_equal 3, detail.api_snapshot.inactive_employee_payroll_deduction_count
  ensure
    ENV[@connection.api_key_reference] = previous_key
  end

  test "refreshes Vitable remote roster as missing credentials sync run without API key" do
    @employer.update!(vitable_id: "empr_ops_123")

    assert_difference -> { @connection.sync_runs.where(operation: "remote_roster_refresh").count }, 1 do
      post refresh_vitable_remote_roster_path, params: { requested_by: "integration_admin" }
    end

    assert_redirected_to vitable_census_sync_path
    sync = @connection.sync_runs.where(operation: "remote_roster_refresh").recent_first.first
    assert_equal "needs_credentials", sync.status
    assert_match @connection.api_key_reference, sync.error_message
    assert_equal "integration_admin", sync.stats.fetch("requested_by")
  end

  test "remote roster refresh deactivates local benefits for inactive remote employees" do
    @employer.update!(vitable_id: "empr_ops_123")
    deduction = @payroll_run.payroll_deductions.find_by!(enrollment: @enrollment)
    response_class = Data.define(:data)
    gateway_class = Class.new do
      define_method(:initialize) { |_connection| }
      define_method(:list_all_employer_employees) do |_employer_id|
        response_class.new(
          data: [
            {
              id: "empl_remote_inactive_casey",
              member_id: "mem_remote_inactive_casey",
              email: "casey@example.com",
              reference_id: "musto_employee_#{Employee.find_by!(email: "casey@example.com").id}",
              status: "inactive"
            }
          ]
        )
      end
    end
    previous_key = ENV[@connection.api_key_reference]
    ENV[@connection.api_key_reference] = "vit_apk_test_value"

    result = Vitable::RefreshRemoteRosterCommand.new(
      dto: Vitable::RefreshRemoteRosterDto.new(requested_by: "integration_admin"),
      gateway_class:
    ).call

    assert result.success?
    sync = @connection.sync_runs.where(operation: "remote_roster_refresh").recent_first.first

    assert_equal "terminated", @employee.reload.employment_status
    assert_equal "inactive", @enrollment.reload.status
    assert_equal 0, deduction.reload.amount_cents
    assert_equal "inactive", deduction.status
    assert_equal "vitable_remote_roster", deduction.metadata.fetch("source")
    assert_equal 3, sync.stats.fetch("inactive_enrollment_count")
    assert_equal 3, sync.stats.fetch("inactive_payroll_deduction_count")
    assert_equal 3, @employer.reload.settings.dig("vitable_remote_roster", "lifecycle_reconciliation", "inactive_enrollment_count")
  ensure
    ENV[@connection.api_key_reference] = previous_key
  end

  test "remote roster refresh fails when employee response omits remote employee id" do
    @employer.update!(vitable_id: "empr_ops_123")
    response_class = Data.define(:data)
    gateway_class = Class.new do
      define_method(:initialize) { |_connection| }
      define_method(:list_all_employer_employees) do |_employer_id|
        response_class.new(
          data: [
            {
              member_id: "mem_remote_casey_missing_employee_id",
              email: "casey@example.com",
              reference_id: "musto_employee_#{Employee.find_by!(email: "casey@example.com").id}",
              status: "active",
              access_token: "vit_at_bad_roster_response"
            }
          ]
        )
      end
    end
    previous_key = ENV[@connection.api_key_reference]
    ENV[@connection.api_key_reference] = "vit_apk_test_value"

    result = Vitable::RefreshRemoteRosterCommand.new(
      dto: Vitable::RefreshRemoteRosterDto.new(requested_by: "integration_admin"),
      gateway_class:
    ).call

    assert result.failure?
    assert_nil @employee.reload.vitable_id
    assert_nil @employee.metadata.fetch("vitable_member_id", nil)
    assert_nil @employer.reload.settings.to_h.fetch("vitable_remote_roster", nil)
    sync = @connection.sync_runs.where(operation: "remote_roster_refresh").recent_first.first
    assert_equal "failed", sync.status
    assert_match "remote employee ID", sync.error_message
    assert_equal "ArgumentError", sync.stats.fetch("error_class")
    assert_equal "mem_remote_casey_missing_employee_id", sync.stats.dig("remote_response", "data", 0, "member_id")
    assert_equal "[FILTERED]", sync.stats.dig("remote_response", "data", 0, "access_token")
    assert_match "remote employee ID", result.errors.to_sentence
    assert_not_includes sync.stats.to_json, "vit_at_bad_roster_response"
  ensure
    ENV[@connection.api_key_reference] = previous_key
  end

  test "remote roster refresh fails when roster response omits data array" do
    @employer.update!(vitable_id: "empr_ops_123")
    response_class = Data.define(:employees)
    gateway_class = Class.new do
      define_method(:initialize) { |_connection| }
      define_method(:list_all_employer_employees) { |_employer_id| response_class.new(employees: []) }
    end
    previous_key = ENV[@connection.api_key_reference]
    ENV[@connection.api_key_reference] = "vit_apk_test_value"

    result = Vitable::RefreshRemoteRosterCommand.new(
      dto: Vitable::RefreshRemoteRosterDto.new(requested_by: "integration_admin"),
      gateway_class:
    ).call

    assert result.failure?
    assert_nil @employer.reload.settings.to_h.fetch("vitable_remote_roster", nil)
    sync = @connection.sync_runs.where(operation: "remote_roster_refresh").recent_first.first
    assert_equal "failed", sync.status
    assert_match "remote roster response", sync.error_message
    assert_match "data array", result.errors.to_sentence
  ensure
    ENV[@connection.api_key_reference] = previous_key
  end

  test "successful remote roster refresh stores Vitable employee IDs" do
    @employer.update!(vitable_id: "empr_ops_123")
    Vitable::GenerateCensusManifestCommand.new(dto: Vitable::GenerateCensusManifestDto.new(requested_by: "ops_test")).call
    response_class = Data.define(:data)
    gateway_class = Class.new do
      define_method(:initialize) { |_connection| }
      define_method(:submit_census_sync) do |employer_id, employees|
        response_class.new(data: { employer_id:, accepted_at: Time.current, employee_count: employees.count })
      end
      define_method(:list_all_employer_employees) do |_employer_id|
        response_class.new(
          data: [
            {
              id: "empl_remote_casey",
              email: "casey@example.com",
              first_name: "Casey",
              last_name: "Nguyen",
              reference_id: "musto_employee_#{Employee.find_by!(email: "casey@example.com").id}",
              status: "active",
              member_id: "mem_remote_casey",
              deductions: [
                {
                  id: "ded_remote_casey_primary",
                  benefit_name: "Primary Care",
                  deduction_amount_in_cents: 9900,
                  deduction_category: nil,
                  frequency: "bi_weekly",
                  period_start_date: Date.current.beginning_of_month,
                  period_end_date: Date.current.end_of_month,
                  tax_classification: "Post-tax"
                }
              ]
            }
          ]
        )
      end
    end
    previous_key = ENV[@connection.api_key_reference]
    ENV[@connection.api_key_reference] = "vit_apk_test_value"

    submit_result = Vitable::SubmitCensusSyncCommand.new(
      dto: Vitable::SubmitCensusSyncDto.new(requested_by: "integration_admin"),
      gateway_class:
    ).call
    @employee.update!(employment_status: "terminated")
    result = Vitable::RefreshRemoteRosterCommand.new(
      dto: Vitable::RefreshRemoteRosterDto.new(requested_by: "integration_admin"),
      gateway_class:
    ).call

    assert submit_result.success?
    assert result.success?
    assert_equal "empl_remote_casey", @employee.reload.vitable_id
    assert_equal "active", @employee.employment_status
    assert_equal "synced", @employee.metadata.fetch("vitable_census_sync_status")
    assert_equal "active", @employee.metadata.fetch("vitable_remote_status")
    assert_equal "mem_remote_casey", @employee.metadata.fetch("vitable_member_id")
    assert_equal 1, @employee.metadata.fetch("vitable_remote_deductions").count
    remote_deduction = @payroll_run.payroll_deductions.find_by!(vitable_id: "ded_remote_casey_primary")
    assert_equal @employee.id, remote_deduction.employee_id
    assert_equal @enrollment.id, remote_deduction.enrollment_id
    assert_equal "VITABLE_PRIMARY_CARE", remote_deduction.code
    assert_equal 9900, remote_deduction.amount_cents
    assert_equal "ready", remote_deduction.status
    assert_equal "vitable_remote_roster", remote_deduction.metadata.fetch("source")
    assert_equal "bi_weekly", remote_deduction.metadata.fetch("frequency")
    manifest_line = @employer.reload.settings.fetch("vitable_census_sync_batch").fetch("employees").first
    assert_equal "synced", manifest_line.fetch("status")
    assert_equal "empl_remote_casey", manifest_line.fetch("remote_employee_id")
    assert_equal "mem_remote_casey", manifest_line.fetch("remote_member_id")
    assert_equal 1, manifest_line.fetch("remote_deduction_count")
    sync = @connection.sync_runs.where(operation: "remote_roster_refresh").recent_first.first
    assert_equal "succeeded", sync.status
    assert_equal 1, sync.stats.fetch("remote_employee_count")
    assert_equal 1, sync.stats.fetch("matched_employee_count")
    assert_equal 1, sync.stats.fetch("manifest_synced_count")
    assert_equal 1, sync.stats.fetch("deduction_created_count")
    assert_equal 0, sync.stats.fetch("deduction_updated_count")
    assert_equal 1, @employer.reload.settings.dig("vitable_remote_roster", "deduction_sync", "created_count")
    assert_equal "verified", sync.stats.fetch("verification_status")
    verification = @employer.reload.settings.fetch("vitable_census_roster_verification")
    assert_equal "verified", verification.fetch("status")
    assert_equal 1, verification.fetch("submitted_count")
    assert_equal 1, verification.fetch("matched_submitted_count")
    assert_equal 0, verification.fetch("missing_submitted_count")
    detail = Vitable::CensusSyncQuery.new.call
    assert_instance_of Vitable::CensusRosterVerificationDto, detail.latest_verification
    assert_equal "verified", detail.latest_verification.status
  ensure
    ENV[@connection.api_key_reference] = previous_key
  end

  test "remote roster refresh detects partial census sync processing" do
    @employer.update!(vitable_id: "empr_ops_123")
    missing_employee = create_census_ready_employee
    Vitable::GenerateCensusManifestCommand.new(dto: Vitable::GenerateCensusManifestDto.new(requested_by: "ops_test")).call
    response_class = Data.define(:data)
    gateway_class = Class.new do
      define_method(:initialize) { |_connection| }
      define_method(:submit_census_sync) do |employer_id, employees|
        response_class.new(data: { employer_id:, accepted_at: Time.current, employee_count: employees.count })
      end
      define_method(:list_all_employer_employees) do |_employer_id|
        response_class.new(
          data: [
            {
              id: "empl_remote_casey",
              member_id: "mem_remote_casey",
              email: "casey@example.com",
              first_name: "Casey",
              last_name: "Nguyen",
              reference_id: "musto_employee_#{Employee.find_by!(email: "casey@example.com").id}",
              status: "active"
            }
          ]
        )
      end
    end
    previous_key = ENV[@connection.api_key_reference]
    ENV[@connection.api_key_reference] = "vit_apk_test_value"

    submit_result = Vitable::SubmitCensusSyncCommand.new(
      dto: Vitable::SubmitCensusSyncDto.new(requested_by: "integration_admin"),
      gateway_class:
    ).call
    refresh_result = Vitable::RefreshRemoteRosterCommand.new(
      dto: Vitable::RefreshRemoteRosterDto.new(requested_by: "integration_admin"),
      gateway_class:
    ).call

    assert submit_result.success?
    assert refresh_result.success?
    verification = @employer.reload.settings.fetch("vitable_census_roster_verification")
    missing_reference_id = "musto_employee_#{missing_employee.id}"
    assert_equal "needs_review", verification.fetch("status")
    assert_equal 2, verification.fetch("submitted_count")
    assert_equal 1, verification.fetch("matched_submitted_count")
    assert_equal 1, verification.fetch("missing_submitted_count")
    assert_equal [ missing_reference_id ], verification.fetch("missing_reference_ids")
    assert_equal "remote_pending", missing_employee.reload.metadata.fetch("vitable_census_sync_status")
    manifest_by_reference = @employer.settings.fetch("vitable_census_sync_batch").fetch("employees").index_by { |line| line.fetch("reference_id") }
    assert_equal "remote_pending", manifest_by_reference.fetch(missing_reference_id).fetch("status")
    assert_equal "synced", manifest_by_reference.fetch("musto_employee_#{@employee.id}").fetch("status")
    sync = @connection.sync_runs.where(operation: "remote_roster_refresh").recent_first.first
    assert_equal "needs_review", sync.stats.fetch("verification_status")
    assert_equal 1, sync.stats.fetch("missing_submitted_count")
    detail = Vitable::CensusSyncQuery.new.call
    assert_equal "needs_review", detail.latest_verification.status
    assert_equal "1/2", detail.metrics.find { |metric| metric.label == "Roster verification" }.value
    assert_equal "needs_review", detail.preflight_checks.find { |check| check.label == "Async roster verification" }.status
  ensure
    ENV[@connection.api_key_reference] = previous_key
  end

  test "embedded enrollment sessions workspace exposes token readiness DTOs" do
    @employee.update!(vitable_id: "empl_ops_casey")
    holdback_employee = create_embedded_session_holdback_employee
    Vitable::GenerateEmbeddedSessionsCommand.new(dto: Vitable::GenerateEmbeddedSessionsDto.new(requested_by: "ops_test")).call
    detail = Vitable::EmbeddedSessionsQuery.new.call

    assert_instance_of Vitable::EmbeddedSessionsCenterDto, detail
    assert_instance_of Vitable::EmbeddedSessionMetricDto, detail.metrics.first
    assert_instance_of Vitable::EmbeddedSessionPreflightCheckDto, detail.preflight_checks.first
    assert_instance_of Vitable::EmbeddedSessionPacketDto, detail.latest_packet
    assert_instance_of Vitable::EmbeddedSessionEmployeeDto, detail.employees.first
    assert_instance_of Vitable::EmbeddedSessionHoldbackDto, detail.holdbacks.first
    assert_equal @employee.id, detail.employees.first.employee_id
    assert_equal holdback_employee.id, detail.holdbacks.first.employee_id

    get vitable_embedded_sessions_path

    assert_response :success
    assert_select "h1", "Embedded enrollment sessions"
    assert_select "h2", "Issue preflight"
    assert_select "h2", "Session-ready employees"
    assert_select "h2", "Session holdbacks"
    assert_select "h2", "Token attempts"
    assert_select "h2", "Session issuance activity"
    assert_select "[data-controller='vitable-drops'][data-vitable-drops-widget-value='employee-dashboard']", 1
    assert_select "button", "Open widget"
  end

  test "generates a Vitable embedded enrollment session packet" do
    @employee.update!(vitable_id: "empl_ops_casey")

    post generate_vitable_embedded_sessions_path, params: { requested_by: "integration_admin" }

    assert_redirected_to vitable_embedded_sessions_path
    packet = @employer.reload.settings.fetch("vitable_embedded_sessions_packet")
    assert_match(/\Avitable_embedded_sessions_#{@employer.id}_/, packet.fetch("packet_id"))
    assert_equal "integration_admin", packet.fetch("requested_by")
    assert_equal "ready", packet.fetch("status")
    assert_equal 1, packet.fetch("totals").fetch("employee_count")
    assert_equal 1, packet.fetch("totals").fetch("ready_count")
    assert_equal 0, packet.fetch("totals").fetch("holdback_count")
    assert_equal 2, packet.fetch("totals").fetch("pending_election_count")
    assert_equal "employee", packet.fetch("token_request").fetch("bound_entity_type")
    assert_equal "X-Musto-Widget-Launch", packet.fetch("token_request").fetch("authorization_header")
    assert_equal @employee.vitable_id, packet.fetch("employees").first.fetch("remote_employee_id")

    launch_authorization = packet.fetch("employees").first.fetch("launch_authorization")
    verification = Vitable::WidgetLaunchToken.verify(launch_authorization.fetch("token"))
    assert verification.success?
    assert_equal @employer.id, verification.claims.employer_id
    assert_equal @employee.id, verification.claims.employee_id
    assert_equal "X-Musto-Widget-Launch", launch_authorization.fetch("header")

    detail = Vitable::EmbeddedSessionsQuery.new.call
    assert_equal "https://app.vitablehealth.com", detail.widget_base_url
    assert detail.employees.first.launch_token.present?
  end

  test "embedded session packet holds back employees with terminated Vitable eligibility and pending elections" do
    @employee.update!(
      vitable_id: "empl_ops_casey",
      metadata: @employee.metadata.to_h.merge("vitable_eligibility_status" => "terminated")
    )

    post generate_vitable_embedded_sessions_path, params: { requested_by: "integration_admin" }

    assert_redirected_to vitable_embedded_sessions_path
    packet = @employer.reload.settings.fetch("vitable_embedded_sessions_packet")

    assert_equal "blocked", packet.fetch("status")
    assert_equal 0, packet.fetch("totals").fetch("ready_count")
    assert_equal 1, packet.fetch("totals").fetch("holdback_count")
    assert_empty packet.fetch("employees")
    assert_equal @employee.id, packet.fetch("holdbacks").first.fetch("employee_id")
    assert_equal "eligibility_terminated", packet.fetch("holdbacks").first.fetch("reason_code")
    assert_match "eligibility is terminated", packet.fetch("holdbacks").first.fetch("reason")

    detail = Vitable::EmbeddedSessionsQuery.new.call
    assert_equal @employee.id, detail.holdbacks.first.employee_id
    assert_equal "eligibility_terminated", detail.holdbacks.first.reason_code
  end

  test "issues embedded enrollment session as missing credentials sync run without API key" do
    @employee.update!(vitable_id: "empl_ops_casey")
    Vitable::GenerateEmbeddedSessionsCommand.new(dto: Vitable::GenerateEmbeddedSessionsDto.new(requested_by: "ops_test")).call

    assert_difference -> { @connection.sync_runs.where(operation: "embedded_enrollment_token").count }, 1 do
      post issue_vitable_embedded_session_path(@employee), params: { requested_by: "integration_admin" }
    end

    assert_redirected_to vitable_embedded_sessions_path
    sync = @connection.sync_runs.where(operation: "embedded_enrollment_token").recent_first.first
    assert_equal "needs_credentials", sync.status
    assert_match @connection.api_key_reference, sync.error_message
    assert_equal @employee.vitable_id, sync.stats.dig("bound_entity", "id")
    assert_equal "integration_admin", sync.stats.fetch("requested_by")
    assert_not_includes sync.stats.to_json, "vit_at_"
  end

  test "embedded session command blocks pending enrollment launch after Vitable eligibility termination" do
    @employee.update!(
      vitable_id: "empl_ops_casey",
      metadata: @employee.metadata.to_h.merge("vitable_eligibility_status" => "terminated")
    )
    gateway_class = Class.new do
      define_method(:initialize) { |_connection| }
      define_method(:issue_employee_access_token) { |_employee_id| raise "token should not be issued" }
    end

    result = Vitable::IssueEmbeddedSessionCommand.new(
      dto: Vitable::IssueEmbeddedSessionDto.new(employee_id: @employee.id, requested_by: "integration_admin"),
      gateway_class:
    ).call

    assert_not result.success?
    assert_match "eligibility is terminated", result.errors.to_sentence
    sync = @connection.sync_runs.where(operation: "embedded_enrollment_token").recent_first.first
    assert_equal "blocked", sync.status
    assert_equal "eligibility_terminated", sync.stats.dig("line", "reason_code")
    assert_match "eligibility is terminated", sync.error_message
  end

  test "successful embedded session command redacts token response" do
    @employee.update!(vitable_id: "empl_ops_casey")
    response_class = Data.define(:access_token, :expires_in, :token_type, :bound_entity, :nested)
    gateway_class = Class.new do
      define_method(:initialize) { |_connection| }
      define_method(:issue_employee_access_token) do |employee_id|
        response_class.new(
          access_token: "vit_at_secret_value",
          expires_in: 3_600,
          token_type: "Bearer",
          bound_entity: { id: employee_id, type: "employee" },
          nested: {
            refresh_token: "vit_rt_nested_secret",
            launch_token: "launch_nested_secret",
            token_type: "Bearer"
          }
        )
      end
    end
    previous_key = ENV[@connection.api_key_reference]
    ENV[@connection.api_key_reference] = "vit_apk_test_value"

    result = Vitable::IssueEmbeddedSessionCommand.new(
      dto: Vitable::IssueEmbeddedSessionDto.new(employee_id: @employee.id, requested_by: "integration_admin"),
      gateway_class:
    ).call

    assert result.success?
    sync = @connection.sync_runs.where(operation: "embedded_enrollment_token").recent_first.first
    assert_equal "succeeded", sync.status
    assert_equal "[FILTERED]", sync.stats.dig("token_response", "access_token")
    assert_equal "[FILTERED]", sync.stats.dig("token_response", "nested", "refresh_token")
    assert_equal "[FILTERED]", sync.stats.dig("token_response", "nested", "launch_token")
    assert_equal "Bearer", sync.stats.dig("token_response", "nested", "token_type")
    assert_equal 3_600, sync.stats.dig("token_response", "expires_in")
    assert_equal "issued", sync.stats.dig("issuance", "status")
    assert_equal @employee.vitable_id, sync.stats.dig("issuance", "bound_entity", "id")
    assert_equal true, sync.stats.dig("issuance", "token_present")
    assert_not_includes sync.stats.to_json, "vit_at_secret_value"
    assert_not_includes sync.stats.to_json, "vit_rt_nested_secret"
    assert_not_includes sync.stats.to_json, "launch_nested_secret"

    @employee.reload
    assert_equal "issued", @employee.metadata.dig("vitable_embedded_session", "status")
    assert_equal sync.id, @employee.metadata.dig("vitable_embedded_session", "sync_run_id")
    assert_not_includes @employee.metadata.to_json, "vit_at_secret_value"

    packet_line = @employer.reload.settings.fetch("vitable_embedded_sessions_packet").fetch("employees").first
    assert_equal "session_issued", packet_line.fetch("status")
    assert_equal "issued", packet_line.dig("latest_session", "status")
    assert_equal @employee.vitable_id, packet_line.dig("latest_session", "bound_entity", "id")

    detail = Vitable::EmbeddedSessionsQuery.new.call
    employee_line = detail.employees.first
    assert_equal "issued", employee_line.session_status
    assert employee_line.session_active?
  ensure
    ENV[@connection.api_key_reference] = previous_key
  end

  test "embedded session command fails when token response omits access token" do
    @employee.update!(vitable_id: "empl_ops_casey")
    response_class = Data.define(:expires_in, :token_type, :bound_entity)
    gateway_class = Class.new do
      define_method(:initialize) { |_connection| }
      define_method(:issue_employee_access_token) do |employee_id|
        response_class.new(expires_in: 3_600, token_type: "Bearer", bound_entity: { id: employee_id, type: "employee" })
      end
    end
    previous_key = ENV[@connection.api_key_reference]
    ENV[@connection.api_key_reference] = "vit_apk_test_value"

    result = Vitable::IssueEmbeddedSessionCommand.new(
      dto: Vitable::IssueEmbeddedSessionDto.new(employee_id: @employee.id, requested_by: "integration_admin"),
      gateway_class:
    ).call

    assert result.failure?
    assert_nil @employee.reload.metadata.to_h.fetch("vitable_embedded_session", nil)
    sync = @connection.sync_runs.where(operation: "embedded_enrollment_token").recent_first.first
    assert_equal "failed", sync.status
    assert_match "access token", sync.error_message
    assert_match "access token", result.errors.to_sentence
  ensure
    ENV[@connection.api_key_reference] = previous_key
  end

  test "embedded session command fails when token response omits expiry" do
    @employee.update!(vitable_id: "empl_ops_casey")
    response_class = Data.define(:access_token, :token_type, :bound_entity)
    gateway_class = Class.new do
      define_method(:initialize) { |_connection| }
      define_method(:issue_employee_access_token) do |employee_id|
        response_class.new(access_token: "vit_at_secret_value", token_type: "Bearer", bound_entity: { id: employee_id, type: "employee" })
      end
    end
    previous_key = ENV[@connection.api_key_reference]
    ENV[@connection.api_key_reference] = "vit_apk_test_value"

    result = Vitable::IssueEmbeddedSessionCommand.new(
      dto: Vitable::IssueEmbeddedSessionDto.new(employee_id: @employee.id, requested_by: "integration_admin"),
      gateway_class:
    ).call

    assert result.failure?
    assert_nil @employee.reload.metadata.to_h.fetch("vitable_embedded_session", nil)
    sync = @connection.sync_runs.where(operation: "embedded_enrollment_token").recent_first.first
    assert_equal "failed", sync.status
    assert_match "expires_in", sync.error_message
    assert_equal "ArgumentError", sync.stats.fetch("error_class")
    assert_equal "[FILTERED]", sync.stats.dig("token_response", "access_token")
    assert_equal "Bearer", sync.stats.dig("token_response", "token_type")
    assert_match "expires_in", result.errors.to_sentence
    assert_not_includes sync.stats.to_json, "vit_at_secret_value"
  ensure
    ENV[@connection.api_key_reference] = previous_key
  end

  test "embedded session command fails when token response is bound to another employee" do
    @employee.update!(vitable_id: "empl_ops_casey")
    response_class = Data.define(:access_token, :expires_in, :token_type, :bound_entity)
    gateway_class = Class.new do
      define_method(:initialize) { |_connection| }
      define_method(:issue_employee_access_token) do |_employee_id|
        response_class.new(
          access_token: "vit_at_wrong_employee_secret",
          expires_in: 3_600,
          token_type: "Bearer",
          bound_entity: { id: "empl_ops_wrong", type: "employee" }
        )
      end
    end
    previous_key = ENV[@connection.api_key_reference]
    ENV[@connection.api_key_reference] = "vit_apk_test_value"

    result = Vitable::IssueEmbeddedSessionCommand.new(
      dto: Vitable::IssueEmbeddedSessionDto.new(employee_id: @employee.id, requested_by: "integration_admin"),
      gateway_class:
    ).call

    assert result.failure?
    assert_nil @employee.reload.metadata.to_h.fetch("vitable_embedded_session", nil)
    sync = @connection.sync_runs.where(operation: "embedded_enrollment_token").recent_first.first
    assert_equal "failed", sync.status
    assert_match "expected empl_ops_casey", sync.error_message
    assert_equal "ArgumentError", sync.stats.fetch("error_class")
    assert_equal "empl_ops_wrong", sync.stats.dig("token_response", "bound_entity", "id")
    assert_equal "[FILTERED]", sync.stats.dig("token_response", "access_token")
    assert_match "expected empl_ops_casey", result.errors.to_sentence
    assert_not_includes sync.stats.to_json, "vit_at_wrong_employee_secret"
  ensure
    ENV[@connection.api_key_reference] = previous_key
  end

  test "vitable employer admin sessions workspace exposes token readiness DTOs" do
    prepare_provisioning_profile(remote_id: "empr_ops_123")
    Vitable::GenerateAdminSessionsCommand.new(dto: Vitable::GenerateAdminSessionsDto.new(requested_by: "ops_test")).call
    detail = Vitable::AdminSessionsQuery.new.call

    assert_instance_of Vitable::AdminSessionsCenterDto, detail
    assert_instance_of Vitable::AdminSessionMetricDto, detail.metrics.first
    assert_instance_of Vitable::AdminSessionPreflightCheckDto, detail.preflight_checks.first
    assert_instance_of Vitable::AdminSessionPacketDto, detail.latest_packet
    assert_instance_of Vitable::AdminSessionWidgetDto, detail.widgets.first
    assert_instance_of Vitable::AdminSessionIssuanceDto, detail.latest_issuance
    assert_equal "ready", detail.latest_packet.status
    assert_equal "Employer benefits", detail.widgets.first.name

    get vitable_admin_sessions_path

    assert_response :success
    assert_select "h1", "Employer admin sessions"
    assert_select "h2", "Launch preflight"
    assert_select "h2", "Embedded admin widgets"
    assert_select "h2", "Token attempts"
    assert_select "[data-controller='vitable-drops'][data-vitable-drops-widget-value='employer-benefits']", 1
    assert_select "[data-controller='vitable-drops'][data-vitable-drops-widget-value='employer-billing']", 1
  end

  test "generates a Vitable employer admin session packet" do
    prepare_provisioning_profile(remote_id: "empr_ops_123")

    post generate_vitable_admin_sessions_path, params: { requested_by: "integration_admin" }

    assert_redirected_to vitable_admin_sessions_path
    packet = @employer.reload.settings.fetch("vitable_admin_sessions_packet")
    assert_match(/\Avitable_admin_sessions_#{@employer.id}_/, packet.fetch("packet_id"))
    assert_equal "integration_admin", packet.fetch("requested_by")
    assert_equal "ready", packet.fetch("status")
    assert_equal "empr_ops_123", packet.fetch("remote_employer_id")
    assert_equal "employer", packet.fetch("token_request").fetch("bound_entity_type")
    assert_equal "/v1/auth/access-tokens", packet.fetch("token_request").fetch("endpoint")
    assert_equal "X-Musto-Widget-Launch", packet.fetch("token_request").fetch("authorization_header")
    assert_equal [ "Employer benefits", "Employer billing" ], packet.fetch("widgets").map { |widget| widget.fetch("name") }
    assert_empty packet.fetch("holdbacks")

    launch_authorization = packet.fetch("launch_authorization")
    verification = Vitable::WidgetLaunchToken.verify(launch_authorization.fetch("token"))
    assert verification.success?
    assert_equal @employer.id, verification.claims.employer_id
    assert_equal "employer", verification.claims.scope

    detail = Vitable::AdminSessionsQuery.new.call
    assert_equal "https://app.vitablehealth.com", detail.widget_base_url
    assert detail.latest_packet.launch_token.present?
  end

  test "issues employer admin session as missing credentials sync run without API key" do
    prepare_provisioning_profile(remote_id: "empr_ops_123")
    Vitable::GenerateAdminSessionsCommand.new(dto: Vitable::GenerateAdminSessionsDto.new(requested_by: "ops_test")).call

    assert_difference -> { @connection.sync_runs.where(operation: "embedded_admin_token").count }, 1 do
      post issue_vitable_admin_session_path, params: { requested_by: "integration_admin" }
    end

    assert_redirected_to vitable_admin_sessions_path
    sync = @connection.sync_runs.where(operation: "embedded_admin_token").recent_first.first
    assert_equal "needs_credentials", sync.status
    assert_match @connection.api_key_reference, sync.error_message
    assert_equal "employer", sync.stats.dig("bound_entity", "type")
    assert_equal "empr_ops_123", sync.stats.dig("bound_entity", "id")
  end

  test "successful employer admin session command redacts token response" do
    prepare_provisioning_profile(remote_id: "empr_ops_123")
    response_class = Data.define(:access_token, :expires_in, :token_type, :bound_entity, :nested)
    gateway_class = Class.new do
      define_method(:initialize) { |_connection| }
      define_method(:issue_employer_access_token) do |employer_id|
        response_class.new(
          access_token: "vit_at_secret_value",
          expires_in: 3_600,
          token_type: "Bearer",
          bound_entity: { id: employer_id, type: "employer" },
          nested: {
            refresh_token: "vit_rt_nested_secret",
            launch_token: "launch_nested_secret",
            token_type: "Bearer"
          }
        )
      end
    end
    previous_key = ENV[@connection.api_key_reference]
    ENV[@connection.api_key_reference] = "vit_apk_test_value"

    result = Vitable::IssueAdminSessionCommand.new(
      dto: Vitable::IssueAdminSessionDto.new(requested_by: "integration_admin"),
      gateway_class:
    ).call

    assert result.success?
    sync = @connection.sync_runs.where(operation: "embedded_admin_token").recent_first.first
    assert_equal "succeeded", sync.status
    assert_equal "[FILTERED]", sync.stats.dig("token_response", "access_token")
    assert_equal "[FILTERED]", sync.stats.dig("token_response", "nested", "refresh_token")
    assert_equal "[FILTERED]", sync.stats.dig("token_response", "nested", "launch_token")
    assert_equal "Bearer", sync.stats.dig("token_response", "nested", "token_type")
    assert_equal true, sync.stats.dig("issuance", "token_present")
    assert_not_includes sync.stats.to_json, "vit_at_secret_value"
    assert_not_includes sync.stats.to_json, "vit_rt_nested_secret"
    assert_not_includes sync.stats.to_json, "launch_nested_secret"

    @employer.reload
    assert_equal "issued", @employer.settings.dig("vitable_admin_session", "status")
    assert_equal sync.id, @employer.settings.dig("vitable_admin_session", "sync_run_id")
    assert_equal "empr_ops_123", @employer.settings.dig("vitable_admin_session", "bound_entity", "id")
    assert_not_includes @employer.settings.to_json, "vit_at_secret_value"

    packet = @employer.settings.fetch("vitable_admin_sessions_packet")
    assert_equal "session_issued", packet.fetch("status")
    assert_equal "issued", packet.dig("latest_session", "status")
    assert_equal [ "session_issued", "session_issued" ], packet.fetch("widgets").map { |widget| widget.fetch("status") }

    detail = Vitable::AdminSessionsQuery.new.call
    assert detail.latest_issuance.active?
  ensure
    ENV[@connection.api_key_reference] = previous_key
  end

  test "employer admin session command fails when token response omits access token" do
    prepare_provisioning_profile(remote_id: "empr_ops_123")
    response_class = Data.define(:expires_in, :token_type, :bound_entity)
    gateway_class = Class.new do
      define_method(:initialize) { |_connection| }
      define_method(:issue_employer_access_token) do |employer_id|
        response_class.new(expires_in: 3_600, token_type: "Bearer", bound_entity: { id: employer_id, type: "employer" })
      end
    end
    previous_key = ENV[@connection.api_key_reference]
    ENV[@connection.api_key_reference] = "vit_apk_test_value"

    result = Vitable::IssueAdminSessionCommand.new(
      dto: Vitable::IssueAdminSessionDto.new(requested_by: "integration_admin"),
      gateway_class:
    ).call

    assert result.failure?
    assert_nil @employer.reload.settings.to_h.fetch("vitable_admin_session", nil)
    sync = @connection.sync_runs.where(operation: "embedded_admin_token").recent_first.first
    assert_equal "failed", sync.status
    assert_match "access token", sync.error_message
    assert_match "access token", result.errors.to_sentence
  ensure
    ENV[@connection.api_key_reference] = previous_key
  end

  test "employer admin session command fails when token response type is not bearer" do
    prepare_provisioning_profile(remote_id: "empr_ops_123")
    response_class = Data.define(:access_token, :expires_in, :token_type, :bound_entity)
    gateway_class = Class.new do
      define_method(:initialize) { |_connection| }
      define_method(:issue_employer_access_token) do |employer_id|
        response_class.new(access_token: "vit_at_secret_value", expires_in: 3_600, token_type: "Basic", bound_entity: { id: employer_id, type: "employer" })
      end
    end
    previous_key = ENV[@connection.api_key_reference]
    ENV[@connection.api_key_reference] = "vit_apk_test_value"

    result = Vitable::IssueAdminSessionCommand.new(
      dto: Vitable::IssueAdminSessionDto.new(requested_by: "integration_admin"),
      gateway_class:
    ).call

    assert result.failure?
    assert_nil @employer.reload.settings.to_h.fetch("vitable_admin_session", nil)
    sync = @connection.sync_runs.where(operation: "embedded_admin_token").recent_first.first
    assert_equal "failed", sync.status
    assert_match "expected Bearer", sync.error_message
    assert_equal "ArgumentError", sync.stats.fetch("error_class")
    assert_equal "Basic", sync.stats.dig("token_response", "token_type")
    assert_equal "[FILTERED]", sync.stats.dig("token_response", "access_token")
    assert_match "expected Bearer", result.errors.to_sentence
    assert_not_includes sync.stats.to_json, "vit_at_secret_value"
  ensure
    ENV[@connection.api_key_reference] = previous_key
  end

  test "employer admin session command fails when token response is bound to another employer" do
    prepare_provisioning_profile(remote_id: "empr_ops_123")
    response_class = Data.define(:access_token, :expires_in, :token_type, :bound_entity)
    gateway_class = Class.new do
      define_method(:initialize) { |_connection| }
      define_method(:issue_employer_access_token) do |_employer_id|
        response_class.new(
          access_token: "vit_at_wrong_employer_secret",
          expires_in: 3_600,
          token_type: "Bearer",
          bound_entity: { id: "empr_ops_wrong", type: "employer" }
        )
      end
    end
    previous_key = ENV[@connection.api_key_reference]
    ENV[@connection.api_key_reference] = "vit_apk_test_value"

    result = Vitable::IssueAdminSessionCommand.new(
      dto: Vitable::IssueAdminSessionDto.new(requested_by: "integration_admin"),
      gateway_class:
    ).call

    assert result.failure?
    assert_nil @employer.reload.settings.to_h.fetch("vitable_admin_session", nil)
    sync = @connection.sync_runs.where(operation: "embedded_admin_token").recent_first.first
    assert_equal "failed", sync.status
    assert_match "expected empr_ops_123", sync.error_message
    assert_equal "ArgumentError", sync.stats.fetch("error_class")
    assert_equal "empr_ops_wrong", sync.stats.dig("token_response", "bound_entity", "id")
    assert_equal "[FILTERED]", sync.stats.dig("token_response", "access_token")
    assert_match "expected empr_ops_123", result.errors.to_sentence
    assert_not_includes sync.stats.to_json, "vit_at_wrong_employer_secret"
  ensure
    ENV[@connection.api_key_reference] = previous_key
  end

  test "care groups workspace exposes group and member DTOs" do
    prepare_care_group_profile(remote_group_id: "grp_ops_123")
    holdback_employee = create_care_member_holdback_employee
    Vitable::GenerateCareGroupPacketCommand.new(dto: Vitable::GenerateCareGroupPacketDto.new(requested_by: "ops_test")).call
    Vitable::GenerateCareMemberSyncCommand.new(dto: Vitable::GenerateCareMemberSyncDto.new(requested_by: "ops_test")).call

    detail = Vitable::CareGroupQuery.new.call

    assert_instance_of Vitable::CareGroupCenterDto, detail
    assert_instance_of Vitable::CareGroupMetricDto, detail.metrics.first
    assert_instance_of Vitable::CareGroupPreflightCheckDto, detail.preflight_checks.first
    assert_instance_of Vitable::CareGroupPacketDto, detail.group_packet
    assert_instance_of Vitable::CareMemberSyncManifestDto, detail.member_manifest
    assert_instance_of Vitable::CareMemberSyncMemberDto, detail.members.first
    assert_instance_of Vitable::CareMemberSyncHoldbackDto, detail.holdbacks.first
    assert_equal @employee.id, detail.members.first.employee_id
    assert_equal holdback_employee.id, detail.holdbacks.first.employee_id
    assert_equal "update", detail.group_packet.mode
    assert_equal "grp_ops_123", detail.remote_group_id

    get vitable_care_groups_path

    assert_response :success
    assert_select "h1", "Care groups"
    assert_select "h2", "Member sync preflight"
    assert_select "h2", "Ready members"
    assert_select "h2", "Member holdbacks"
    assert_select "h2", "Sync attempts"
    assert_select "h2", "API activity"
    assert_select "button", "Refresh member sync"
  end

  test "generates a Vitable care group packet through command action" do
    prepare_care_group_profile

    post generate_vitable_care_group_packet_path, params: { requested_by: "integration_admin" }

    assert_redirected_to vitable_care_groups_path
    packet = @employer.reload.settings.fetch("vitable_care_group_packet")
    assert_match(/\Avitable_care_group_#{@employer.id}_/, packet.fetch("packet_id"))
    assert_equal "integration_admin", packet.fetch("requested_by")
    assert_equal "create", packet.fetch("mode")
    assert_equal "ready", packet.fetch("status")
    assert_equal "/v1/groups", packet.fetch("endpoint")
    assert_equal "musto_care_group_#{@employer.id}", packet.fetch("api_payload").fetch("external_reference_id")
    assert_equal @employer.name, packet.fetch("api_payload").fetch("name")
    assert_empty packet.fetch("holdbacks")
  end

  test "submits care group as missing credentials sync run without API key" do
    prepare_care_group_profile
    Vitable::GenerateCareGroupPacketCommand.new(dto: Vitable::GenerateCareGroupPacketDto.new(requested_by: "ops_test")).call

    assert_difference -> { @connection.sync_runs.where(operation: "care_group_upsert").count }, 1 do
      post submit_vitable_care_group_path, params: { requested_by: "integration_admin" }
    end

    assert_redirected_to vitable_care_groups_path
    sync = @connection.sync_runs.where(operation: "care_group_upsert").recent_first.first
    assert_equal "needs_credentials", sync.status
    assert_match @connection.api_key_reference, sync.error_message
    assert_equal "integration_admin", sync.stats.fetch("requested_by")
    assert_equal @employer.name, sync.stats.dig("payload", "name")
  end

  test "successful care group submit stores remote group id" do
    prepare_care_group_profile
    response_class = Data.define(:data)
    gateway_class = Class.new do
      define_method(:initialize) { |_connection| }
      define_method(:create_group) do |payload|
        response_class.new(
          data: {
            id: "grp_created_123",
            name: payload.fetch("name"),
            external_reference_id: payload.fetch("external_reference_id"),
            api_key: "vit_apk_group_snapshot_secret"
          }
        )
      end
    end
    previous_key = ENV[@connection.api_key_reference]
    ENV[@connection.api_key_reference] = "vit_apk_test_value"

    result = Vitable::SubmitCareGroupCommand.new(
      dto: Vitable::SubmitCareGroupDto.new(requested_by: "integration_admin"),
      gateway_class:
    ).call

    assert result.success?
    assert_equal "grp_created_123", @employer.reload.settings.fetch("vitable_care_group_id")
    sync = @connection.sync_runs.where(operation: "care_group_upsert").recent_first.first
    assert_equal "succeeded", sync.status
    assert_equal "grp_created_123", sync.stats.fetch("remote_group_id")
    assert_equal "[FILTERED]", sync.stats.dig("remote_response", "data", "api_key")
    assert_not_includes sync.stats.to_json, "vit_apk_group_snapshot_secret"
  ensure
    ENV[@connection.api_key_reference] = previous_key
  end

  test "care group submit fails when create response omits remote group id" do
    prepare_care_group_profile
    response_class = Data.define(:data)
    gateway_class = Class.new do
      define_method(:initialize) { |_connection| }
      define_method(:create_group) do |payload|
        response_class.new(data: { name: payload.fetch("name"), api_key: "vit_apk_bad_group_response" })
      end
    end
    previous_key = ENV[@connection.api_key_reference]
    ENV[@connection.api_key_reference] = "vit_apk_test_value"

    result = Vitable::SubmitCareGroupCommand.new(
      dto: Vitable::SubmitCareGroupDto.new(requested_by: "integration_admin"),
      gateway_class:
    ).call

    assert result.failure?
    assert_nil @employer.reload.settings.to_h.fetch("vitable_care_group_id", nil)
    sync = @connection.sync_runs.where(operation: "care_group_upsert").recent_first.first
    assert_equal "failed", sync.status
    assert_match "remote group ID", sync.error_message
    assert_equal "ArgumentError", sync.stats.fetch("error_class")
    assert_equal @employer.name, sync.stats.dig("remote_response", "data", "name")
    assert_equal "[FILTERED]", sync.stats.dig("remote_response", "data", "api_key")
    assert_match "remote group ID", result.errors.to_sentence
    assert_not_includes sync.stats.to_json, "vit_apk_bad_group_response"
  ensure
    ENV[@connection.api_key_reference] = previous_key
  end

  test "care group submit fails when create response external reference differs from packet" do
    prepare_care_group_profile
    response_class = Data.define(:data)
    gateway_class = Class.new do
      define_method(:initialize) { |_connection| }
      define_method(:create_group) do |payload|
        response_class.new(
          data: {
            id: "grp_created_wrong_reference",
            name: payload.fetch("name"),
            external_reference_id: "musto_care_group_wrong"
          }
        )
      end
    end
    previous_key = ENV[@connection.api_key_reference]
    ENV[@connection.api_key_reference] = "vit_apk_test_value"

    result = Vitable::SubmitCareGroupCommand.new(
      dto: Vitable::SubmitCareGroupDto.new(requested_by: "integration_admin"),
      gateway_class:
    ).call

    assert result.failure?
    assert_nil @employer.reload.settings.to_h.fetch("vitable_care_group_id", nil)
    sync = @connection.sync_runs.where(operation: "care_group_upsert").recent_first.first
    assert_equal "failed", sync.status
    assert_match "expected musto_care_group_#{@employer.id}", sync.error_message
    assert_match "expected musto_care_group_#{@employer.id}", result.errors.to_sentence
  ensure
    ENV[@connection.api_key_reference] = previous_key
  end

  test "care group update fails when response omits remote group id" do
    prepare_care_group_profile(remote_group_id: "grp_ops_123")
    Vitable::GenerateCareGroupPacketCommand.new(dto: Vitable::GenerateCareGroupPacketDto.new(requested_by: "ops_test")).call
    response_class = Data.define(:data)
    gateway_class = Class.new do
      define_method(:initialize) { |_connection| }
      define_method(:update_group) { |_group_id, payload| response_class.new(data: { name: payload.fetch("name") }) }
    end
    previous_key = ENV[@connection.api_key_reference]
    ENV[@connection.api_key_reference] = "vit_apk_test_value"

    result = Vitable::SubmitCareGroupCommand.new(
      dto: Vitable::SubmitCareGroupDto.new(requested_by: "integration_admin"),
      gateway_class:
    ).call

    assert result.failure?
    assert_equal "grp_ops_123", @employer.reload.settings.fetch("vitable_care_group_id")
    sync = @connection.sync_runs.where(operation: "care_group_upsert").recent_first.first
    assert_equal "failed", sync.status
    assert_match "remote group ID", sync.error_message
    assert_match "remote group ID", result.errors.to_sentence
    assert_nil @employer.settings.to_h.fetch("vitable_care_group_last_sync", nil)
  ensure
    ENV[@connection.api_key_reference] = previous_key
  end

  test "care group update fails when response group differs from tracked group" do
    prepare_care_group_profile(remote_group_id: "grp_ops_123")
    Vitable::GenerateCareGroupPacketCommand.new(dto: Vitable::GenerateCareGroupPacketDto.new(requested_by: "ops_test")).call
    response_class = Data.define(:data)
    gateway_class = Class.new do
      define_method(:initialize) { |_connection| }
      define_method(:update_group) do |_group_id, payload|
        response_class.new(
          data: {
            id: "grp_ops_wrong",
            name: payload.fetch("name"),
            external_reference_id: payload.fetch("external_reference_id")
          }
        )
      end
    end
    previous_key = ENV[@connection.api_key_reference]
    ENV[@connection.api_key_reference] = "vit_apk_test_value"

    result = Vitable::SubmitCareGroupCommand.new(
      dto: Vitable::SubmitCareGroupDto.new(requested_by: "integration_admin"),
      gateway_class:
    ).call

    assert result.failure?
    assert_equal "grp_ops_123", @employer.reload.settings.fetch("vitable_care_group_id")
    sync = @connection.sync_runs.where(operation: "care_group_upsert").recent_first.first
    assert_equal "failed", sync.status
    assert_match "expected grp_ops_123", sync.error_message
    assert_match "expected grp_ops_123", result.errors.to_sentence
    assert_nil @employer.settings.to_h.fetch("vitable_care_group_last_sync", nil)
  ensure
    ENV[@connection.api_key_reference] = previous_key
  end

  test "generates a Vitable care member manifest through command action" do
    prepare_care_group_profile(remote_group_id: "grp_ops_123")
    create_care_member_holdback_employee

    post generate_vitable_care_member_manifest_path, params: { requested_by: "integration_admin" }

    assert_redirected_to vitable_care_groups_path
    manifest = @employer.reload.settings.fetch("vitable_care_member_sync_manifest")
    assert_match(/\Avitable_care_members_#{@employer.id}_/, manifest.fetch("manifest_id"))
    assert_equal "integration_admin", manifest.fetch("requested_by")
    assert_equal "needs_review", manifest.fetch("status")
    assert_equal 2, manifest.fetch("totals").fetch("employee_count")
    assert_equal 1, manifest.fetch("totals").fetch("ready_count")
    assert_equal 1, manifest.fetch("totals").fetch("holdback_count")
    assert_equal "plan_care_123", manifest.fetch("members").first.fetch("plan_id")
    assert_equal "missing_remote_plan_id", manifest.fetch("holdbacks").first.fetch("reason_code")
    assert_equal "/v1/groups/:group_id/members/sync", manifest.fetch("endpoint")
  end

  test "Vitable care member manifest normalizes group sync API fields" do
    prepare_care_group_profile(remote_group_id: "grp_ops_123")
    location = @employer.work_locations.find_by!(name: "Ops HQ")
    location.update!(state: "pa", postal_code: " 19106-1234 ")
    @employee.update!(
      email: " CASEY@EXAMPLE.COM ",
      metadata: @employee.metadata.to_h.merge("phone" => "+1 (555) 123-4567")
    )

    post generate_vitable_care_member_manifest_path, params: { requested_by: "integration_admin" }

    manifest = @employer.reload.settings.fetch("vitable_care_member_sync_manifest")
    member_payload = manifest.fetch("api_payload").fetch("members").first

    assert_equal "ready", manifest.fetch("status")
    assert_equal "casey@example.com", member_payload.fetch("email")
    assert_equal "5551234567", member_payload.fetch("phone")
    assert_equal "PA", member_payload.fetch("address").fetch("state")
    assert_equal "19106-1234", member_payload.fetch("address").fetch("zipcode")
    assert_empty manifest.fetch("holdbacks")
  end

  test "Vitable care member manifest holds back invalid group sync API fields" do
    prepare_care_group_profile(remote_group_id: "grp_ops_123")
    location = @employer.work_locations.find_by!(name: "Ops HQ")
    location.update!(state: "Pennsylvania", postal_code: "191")
    @employee.update!(
      email: "casey",
      metadata: @employee.metadata.to_h.merge("phone" => "555123")
    )

    post generate_vitable_care_member_manifest_path, params: { requested_by: "integration_admin" }

    manifest = @employer.reload.settings.fetch("vitable_care_member_sync_manifest")
    holdback = manifest.fetch("holdbacks").first

    assert_equal "blocked", manifest.fetch("status")
    assert_equal 0, manifest.fetch("totals").fetch("ready_count")
    assert_equal "invalid_api_contract_fields", holdback.fetch("reason_code")
    assert_includes holdback.fetch("reason"), "email"
    assert_includes holdback.fetch("reason"), "phone"
    assert_includes holdback.fetch("reason"), "address state"
    assert_includes holdback.fetch("reason"), "address ZIP"
    assert_empty manifest.fetch("api_payload").fetch("members")
  end

  test "submits care member sync as missing credentials sync run without API key" do
    prepare_care_group_profile(remote_group_id: "grp_ops_123")
    Vitable::GenerateCareMemberSyncCommand.new(dto: Vitable::GenerateCareMemberSyncDto.new(requested_by: "ops_test")).call

    assert_difference -> { @connection.sync_runs.where(operation: "care_member_sync_submit").count }, 1 do
      post submit_vitable_care_members_path, params: { requested_by: "integration_admin" }
    end

    assert_redirected_to vitable_care_groups_path
    sync = @connection.sync_runs.where(operation: "care_member_sync_submit").recent_first.first
    assert_equal "needs_credentials", sync.status
    assert_match @connection.api_key_reference, sync.error_message
    assert_equal "integration_admin", sync.stats.fetch("requested_by")
    assert_equal @employee.email, sync.stats.fetch("payload").fetch("members").first.fetch("email")
  end

  test "care member sync submit fails when response omits remote request id" do
    prepare_care_group_profile(remote_group_id: "grp_ops_123")
    Vitable::GenerateCareMemberSyncCommand.new(dto: Vitable::GenerateCareMemberSyncDto.new(requested_by: "ops_test")).call
    response_class = Data.define(:data)
    gateway_class = Class.new do
      define_method(:initialize) { |_connection| }
      define_method(:submit_group_member_sync) do |group_id, members|
        response_class.new(data: { group_id:, accepted_at: Time.current, member_count: members.count })
      end
    end
    previous_key = ENV[@connection.api_key_reference]
    ENV[@connection.api_key_reference] = "vit_apk_test_value"

    result = Vitable::SubmitCareMemberSyncCommand.new(
      dto: Vitable::SubmitCareMemberSyncDto.new(requested_by: "integration_admin"),
      gateway_class:
    ).call

    assert result.failure?
    assert_nil @employer.reload.settings.to_h.fetch("vitable_care_member_sync_last_request", nil)
    sync = @connection.sync_runs.where(operation: "care_member_sync_submit").recent_first.first
    assert_equal "failed", sync.status
    assert_match "remote request ID", sync.error_message
    assert_match "remote request ID", result.errors.to_sentence
  ensure
    ENV[@connection.api_key_reference] = previous_key
  end

  test "care member sync submit fails when response omits accepted timestamp" do
    prepare_care_group_profile(remote_group_id: "grp_ops_123")
    Vitable::GenerateCareMemberSyncCommand.new(dto: Vitable::GenerateCareMemberSyncDto.new(requested_by: "ops_test")).call
    response_class = Data.define(:data)
    gateway_class = Class.new do
      define_method(:initialize) { |_connection| }
      define_method(:submit_group_member_sync) do |group_id, members|
        response_class.new(data: { group_id:, request_id: "grpmsr_ops_missing_acceptance", member_count: members.count })
      end
    end
    previous_key = ENV[@connection.api_key_reference]
    ENV[@connection.api_key_reference] = "vit_apk_test_value"

    result = Vitable::SubmitCareMemberSyncCommand.new(
      dto: Vitable::SubmitCareMemberSyncDto.new(requested_by: "integration_admin"),
      gateway_class:
    ).call

    assert result.failure?
    assert_nil @employer.reload.settings.to_h.fetch("vitable_care_member_sync_last_request", nil)
    member_line = @employer.settings.fetch("vitable_care_member_sync_manifest").fetch("members").first
    assert_not_equal "synced", member_line.fetch("status")
    assert_nil @employee.reload.metadata.fetch("vitable_care_member_sync_status", nil)
    sync = @connection.sync_runs.where(operation: "care_member_sync_submit").recent_first.first
    assert_equal "failed", sync.status
    assert_match "accepted_at", sync.error_message
    assert_match "accepted_at", result.errors.to_sentence
  ensure
    ENV[@connection.api_key_reference] = previous_key
  end

  test "care member sync submit fails when response omits remote group id" do
    prepare_care_group_profile(remote_group_id: "grp_ops_123")
    Vitable::GenerateCareMemberSyncCommand.new(dto: Vitable::GenerateCareMemberSyncDto.new(requested_by: "ops_test")).call
    response_class = Data.define(:data)
    gateway_class = Class.new do
      define_method(:initialize) { |_connection| }
      define_method(:submit_group_member_sync) do |_group_id, members|
        response_class.new(data: { request_id: "grpmsr_ops_missing_group", accepted_at: Time.current, member_count: members.count })
      end
    end
    previous_key = ENV[@connection.api_key_reference]
    ENV[@connection.api_key_reference] = "vit_apk_test_value"

    result = Vitable::SubmitCareMemberSyncCommand.new(
      dto: Vitable::SubmitCareMemberSyncDto.new(requested_by: "integration_admin"),
      gateway_class:
    ).call

    assert result.failure?
    assert_nil @employer.reload.settings.to_h.fetch("vitable_care_member_sync_last_request", nil)
    member_line = @employer.settings.fetch("vitable_care_member_sync_manifest").fetch("members").first
    assert_not_equal "synced", member_line.fetch("status")
    assert_nil @employee.reload.metadata.fetch("vitable_care_member_sync_status", nil)
    sync = @connection.sync_runs.where(operation: "care_member_sync_submit").recent_first.first
    assert_equal "failed", sync.status
    assert_match "remote group ID", sync.error_message
    assert_match "remote group ID", result.errors.to_sentence
  ensure
    ENV[@connection.api_key_reference] = previous_key
  end

  test "care member sync submit fails when response group differs from submitted group" do
    prepare_care_group_profile(remote_group_id: "grp_ops_123")
    Vitable::GenerateCareMemberSyncCommand.new(dto: Vitable::GenerateCareMemberSyncDto.new(requested_by: "ops_test")).call
    response_class = Data.define(:data)
    gateway_class = Class.new do
      define_method(:initialize) { |_connection| }
      define_method(:submit_group_member_sync) do |_group_id, members|
        response_class.new(
          data: {
            group_id: "grp_ops_wrong",
            request_id: "grpmsr_ops_wrong_group",
            accepted_at: Time.current,
            member_count: members.count,
            refresh_token: "vit_rt_wrong_group_response"
          }
        )
      end
    end
    previous_key = ENV[@connection.api_key_reference]
    ENV[@connection.api_key_reference] = "vit_apk_test_value"

    result = Vitable::SubmitCareMemberSyncCommand.new(
      dto: Vitable::SubmitCareMemberSyncDto.new(requested_by: "integration_admin"),
      gateway_class:
    ).call

    assert result.failure?
    assert_nil @employer.reload.settings.to_h.fetch("vitable_care_member_sync_last_request", nil)
    sync = @connection.sync_runs.where(operation: "care_member_sync_submit").recent_first.first
    assert_equal "failed", sync.status
    assert_match "expected grp_ops_123", sync.error_message
    assert_equal "ArgumentError", sync.stats.fetch("error_class")
    assert_equal "grp_ops_wrong", sync.stats.dig("remote_response", "data", "group_id")
    assert_equal "[FILTERED]", sync.stats.dig("remote_response", "data", "refresh_token")
    assert_match "expected grp_ops_123", result.errors.to_sentence
    assert_not_includes sync.stats.to_json, "vit_rt_wrong_group_response"
  ensure
    ENV[@connection.api_key_reference] = previous_key
  end

  test "care member sync refresh fails when response omits remote group id" do
    prepare_care_group_profile(remote_group_id: "grp_ops_123")
    Vitable::GenerateCareMemberSyncCommand.new(dto: Vitable::GenerateCareMemberSyncDto.new(requested_by: "ops_test")).call
    response_class = Data.define(:data)
    gateway_class = Class.new do
      define_method(:initialize) { |_connection| }
      define_method(:submit_group_member_sync) do |group_id, members|
        response_class.new(
          data: {
            group_id:,
            request_id: "grpmsr_ops_missing_refresh_group",
            accepted_at: Time.current,
            member_count: members.count
          }
        )
      end
      define_method(:retrieve_group_member_sync) do |_group_id, request_id|
        response_class.new(
          data: {
            request_id:,
            accepted_at: 1.minute.ago,
            completed_at: Time.current,
            results: {
              added_group_member_ids: [ "grpmem_casey" ],
              removed_group_member_ids: [],
              failures: []
            }
          }
        )
      end
    end
    previous_key = ENV[@connection.api_key_reference]
    ENV[@connection.api_key_reference] = "vit_apk_test_value"

    submit_result = Vitable::SubmitCareMemberSyncCommand.new(
      dto: Vitable::SubmitCareMemberSyncDto.new(requested_by: "integration_admin"),
      gateway_class:
    ).call
    refresh_result = Vitable::RefreshCareMemberSyncCommand.new(
      dto: Vitable::RefreshCareMemberSyncDto.new(requested_by: "integration_admin"),
      gateway_class:
    ).call

    assert submit_result.success?
    assert refresh_result.failure?
    request = @employer.reload.settings.fetch("vitable_care_member_sync_last_request")
    assert_equal "grpmsr_ops_missing_refresh_group", request.fetch("request_id")
    assert_equal "processing", request.fetch("status")
    assert_nil request.fetch("reconciliation", nil)
    assert_nil @employee.reload.metadata.fetch("vitable_care_member_sync_status", nil)
    sync = @connection.sync_runs.where(operation: "care_member_sync_refresh").recent_first.first
    assert_equal "failed", sync.status
    assert_match "remote group ID", sync.error_message
    assert_match "remote group ID", refresh_result.errors.to_sentence
  ensure
    ENV[@connection.api_key_reference] = previous_key
  end

  test "care member sync refresh fails when response group differs from tracked group" do
    prepare_care_group_profile(remote_group_id: "grp_ops_123")
    Vitable::GenerateCareMemberSyncCommand.new(dto: Vitable::GenerateCareMemberSyncDto.new(requested_by: "ops_test")).call
    response_class = Data.define(:data)
    gateway_class = Class.new do
      define_method(:initialize) { |_connection| }
      define_method(:submit_group_member_sync) do |group_id, members|
        response_class.new(
          data: {
            group_id:,
            request_id: "grpmsr_ops_group_expected",
            accepted_at: Time.current,
            member_count: members.count
          }
        )
      end
      define_method(:retrieve_group_member_sync) do |_group_id, request_id|
        response_class.new(
          data: {
            group_id: "grp_ops_wrong",
            request_id:,
            accepted_at: 1.minute.ago,
            completed_at: Time.current,
            results: {
              added_group_member_ids: [ "grpmem_casey" ],
              removed_group_member_ids: [],
              failures: []
            }
          }
        )
      end
    end
    previous_key = ENV[@connection.api_key_reference]
    ENV[@connection.api_key_reference] = "vit_apk_test_value"

    submit_result = Vitable::SubmitCareMemberSyncCommand.new(
      dto: Vitable::SubmitCareMemberSyncDto.new(requested_by: "integration_admin"),
      gateway_class:
    ).call
    refresh_result = Vitable::RefreshCareMemberSyncCommand.new(
      dto: Vitable::RefreshCareMemberSyncDto.new(requested_by: "integration_admin"),
      gateway_class:
    ).call

    assert submit_result.success?
    assert refresh_result.failure?
    request = @employer.reload.settings.fetch("vitable_care_member_sync_last_request")
    assert_equal "grp_ops_123", request.fetch("group_id")
    assert_equal "processing", request.fetch("status")
    assert_nil request.fetch("reconciliation", nil)
    assert_nil @employee.reload.metadata.fetch("vitable_care_member_sync_status", nil)
    sync = @connection.sync_runs.where(operation: "care_member_sync_refresh").recent_first.first
    assert_equal "failed", sync.status
    assert_match "expected grp_ops_123", sync.error_message
    assert_match "expected grp_ops_123", refresh_result.errors.to_sentence
  ensure
    ENV[@connection.api_key_reference] = previous_key
  end

  test "care member sync refresh fails when response request differs from tracked request" do
    prepare_care_group_profile(remote_group_id: "grp_ops_123")
    Vitable::GenerateCareMemberSyncCommand.new(dto: Vitable::GenerateCareMemberSyncDto.new(requested_by: "ops_test")).call
    response_class = Data.define(:data)
    gateway_class = Class.new do
      define_method(:initialize) { |_connection| }
      define_method(:submit_group_member_sync) do |group_id, members|
        response_class.new(
          data: {
            group_id:,
            request_id: "grpmsr_ops_expected",
            accepted_at: Time.current,
            member_count: members.count
          }
        )
      end
      define_method(:retrieve_group_member_sync) do |group_id, _request_id|
        response_class.new(
          data: {
            group_id:,
            request_id: "grpmsr_ops_wrong",
            accepted_at: 1.minute.ago,
            completed_at: Time.current,
            results: {
              added_group_member_ids: [ "grpmem_casey" ],
              removed_group_member_ids: [],
              failures: []
            }
          }
        )
      end
    end
    previous_key = ENV[@connection.api_key_reference]
    ENV[@connection.api_key_reference] = "vit_apk_test_value"

    submit_result = Vitable::SubmitCareMemberSyncCommand.new(
      dto: Vitable::SubmitCareMemberSyncDto.new(requested_by: "integration_admin"),
      gateway_class:
    ).call
    refresh_result = Vitable::RefreshCareMemberSyncCommand.new(
      dto: Vitable::RefreshCareMemberSyncDto.new(requested_by: "integration_admin"),
      gateway_class:
    ).call

    assert submit_result.success?
    assert refresh_result.failure?
    request = @employer.reload.settings.fetch("vitable_care_member_sync_last_request")
    assert_equal "grpmsr_ops_expected", request.fetch("request_id")
    assert_equal "processing", request.fetch("status")
    assert_nil request.fetch("reconciliation", nil)
    assert_nil @employee.reload.metadata.fetch("vitable_care_member_sync_status", nil)
    sync = @connection.sync_runs.where(operation: "care_member_sync_refresh").recent_first.first
    assert_equal "failed", sync.status
    assert_match "expected grpmsr_ops_expected", sync.error_message
    assert_match "expected grpmsr_ops_expected", refresh_result.errors.to_sentence
  ensure
    ENV[@connection.api_key_reference] = previous_key
  end

  test "care member sync refresh fails when completed response omits results" do
    prepare_care_group_profile(remote_group_id: "grp_ops_123")
    Vitable::GenerateCareMemberSyncCommand.new(dto: Vitable::GenerateCareMemberSyncDto.new(requested_by: "ops_test")).call
    response_class = Data.define(:data)
    gateway_class = Class.new do
      define_method(:initialize) { |_connection| }
      define_method(:submit_group_member_sync) do |group_id, members|
        response_class.new(
          data: {
            group_id:,
            request_id: "grpmsr_ops_missing_results",
            accepted_at: Time.current,
            member_count: members.count
          }
        )
      end
      define_method(:retrieve_group_member_sync) do |group_id, request_id|
        response_class.new(
          data: {
            group_id:,
            request_id:,
            accepted_at: 1.minute.ago,
            completed_at: Time.current
          }
        )
      end
    end
    previous_key = ENV[@connection.api_key_reference]
    ENV[@connection.api_key_reference] = "vit_apk_test_value"

    submit_result = Vitable::SubmitCareMemberSyncCommand.new(
      dto: Vitable::SubmitCareMemberSyncDto.new(requested_by: "integration_admin"),
      gateway_class:
    ).call
    refresh_result = Vitable::RefreshCareMemberSyncCommand.new(
      dto: Vitable::RefreshCareMemberSyncDto.new(requested_by: "integration_admin"),
      gateway_class:
    ).call

    assert submit_result.success?
    assert refresh_result.failure?
    request = @employer.reload.settings.fetch("vitable_care_member_sync_last_request")
    assert_equal "processing", request.fetch("status")
    assert_nil request.fetch("reconciliation", nil)
    assert_nil @employee.reload.metadata.fetch("vitable_care_member_sync_status", nil)
    sync = @connection.sync_runs.where(operation: "care_member_sync_refresh").recent_first.first
    assert_equal "failed", sync.status
    assert_match "completed without results", sync.error_message
    assert_match "completed without results", refresh_result.errors.to_sentence
  ensure
    ENV[@connection.api_key_reference] = previous_key
  end

  test "care member sync refresh fails when completed response includes malformed failure rows" do
    prepare_care_group_profile(remote_group_id: "grp_ops_123")
    Vitable::GenerateCareMemberSyncCommand.new(dto: Vitable::GenerateCareMemberSyncDto.new(requested_by: "ops_test")).call
    response_class = Data.define(:data)
    employee_reference_id = "musto_employee_#{@employee.id}"
    gateway_class = Class.new do
      define_method(:initialize) { |_connection| }
      define_method(:submit_group_member_sync) do |group_id, members|
        response_class.new(
          data: {
            group_id:,
            request_id: "grpmsr_ops_bad_failure",
            accepted_at: Time.current,
            member_count: members.count
          }
        )
      end
      define_method(:retrieve_group_member_sync) do |group_id, request_id|
        response_class.new(
          data: {
            group_id:,
            request_id:,
            accepted_at: 1.minute.ago,
            completed_at: Time.current,
            client_secret: "client_secret_bad_failure_response",
            results: {
              added_group_member_ids: [],
              removed_group_member_ids: [],
              failures: [
                {
                  operation: "add",
                  reference_id: employee_reference_id
                }
              ]
            }
          }
        )
      end
    end
    previous_key = ENV[@connection.api_key_reference]
    ENV[@connection.api_key_reference] = "vit_apk_test_value"

    submit_result = Vitable::SubmitCareMemberSyncCommand.new(
      dto: Vitable::SubmitCareMemberSyncDto.new(requested_by: "integration_admin"),
      gateway_class:
    ).call
    refresh_result = Vitable::RefreshCareMemberSyncCommand.new(
      dto: Vitable::RefreshCareMemberSyncDto.new(requested_by: "integration_admin"),
      gateway_class:
    ).call

    assert submit_result.success?
    assert refresh_result.failure?
    request = @employer.reload.settings.fetch("vitable_care_member_sync_last_request")
    assert_equal "processing", request.fetch("status")
    assert_nil request.fetch("reconciliation", nil)
    assert_nil @employee.reload.metadata.fetch("vitable_care_member_sync_status", nil)
    sync = @connection.sync_runs.where(operation: "care_member_sync_refresh").recent_first.first
    assert_equal "failed", sync.status
    assert_match "failure 1 did not include reason", sync.error_message
    assert_equal "ArgumentError", sync.stats.fetch("error_class")
    assert_equal "grpmsr_ops_bad_failure", sync.stats.dig("remote_response", "data", "request_id")
    assert_equal "[FILTERED]", sync.stats.dig("remote_response", "data", "client_secret")
    assert_match "failure 1 did not include reason", refresh_result.errors.to_sentence
    assert_not_includes sync.stats.to_json, "client_secret_bad_failure_response"
  ensure
    ENV[@connection.api_key_reference] = previous_key
  end

  test "successful care member sync stores request status and refresh results" do
    prepare_care_group_profile(remote_group_id: "grp_ops_123")
    care_location = @employer.work_locations.find_by!(name: "Ops HQ")
    failed_employee = @employer.employees.create!(
      first_name: "Jordan",
      last_name: "Review",
      email: "jordan.review@example.com",
      department: @department,
      work_location: care_location,
      title: "Care Reviewer",
      date_of_birth: Date.new(1988, 6, 12),
      start_on: Date.current - 18.months,
      compensation_cents: 91_000_00,
      onboarding_status: "complete",
      metadata: { phone: "5551236677" }
    )
    failed_enrollment = failed_employee.enrollments.create!(benefit_plan: @plan, status: "accepted", effective_on: Date.current.beginning_of_month)
    Vitable::GenerateCareMemberSyncCommand.new(dto: Vitable::GenerateCareMemberSyncDto.new(requested_by: "ops_test")).call
    response_class = Data.define(:data)
    gateway_class = Class.new do
      define_method(:initialize) { |_connection| }
      define_method(:submit_group_member_sync) do |group_id, members|
        response_class.new(
          data: {
            group_id:,
            request_id: "grpmsr_ops_123",
            accepted_at: Time.current,
            member_count: members.count,
            access_token: "vit_at_member_sync_snapshot_secret"
          }
        )
      end
      define_method(:retrieve_group_member_sync) do |group_id, request_id|
        response_class.new(
          data: {
            group_id:,
            request_id:,
            accepted_at: 1.minute.ago,
            completed_at: Time.current,
            refresh_token: "vit_rt_member_sync_snapshot_secret",
            results: {
              added_group_member_ids: [ "grpmem_casey" ],
              removed_group_member_ids: [],
              failures: [
                {
                  operation: "add",
                  reference_id: "musto_employee_#{Employee.find_by!(email: "jordan.review@example.com").id}",
                  reason: "Plan is not available for this member."
                }
              ]
            }
          }
        )
      end
    end
    previous_key = ENV[@connection.api_key_reference]
    ENV[@connection.api_key_reference] = "vit_apk_test_value"

    submit_result = Vitable::SubmitCareMemberSyncCommand.new(
      dto: Vitable::SubmitCareMemberSyncDto.new(requested_by: "integration_admin"),
      gateway_class:
    ).call
    refresh_result = Vitable::RefreshCareMemberSyncCommand.new(
      dto: Vitable::RefreshCareMemberSyncDto.new(requested_by: "integration_admin"),
      gateway_class:
    ).call

    assert submit_result.success?
    assert refresh_result.success?
    request = @employer.reload.settings.fetch("vitable_care_member_sync_last_request")
    assert_equal "grpmsr_ops_123", request.fetch("request_id")
    assert_equal "complete", request.fetch("status")
    assert_equal [ "grpmem_casey" ], request.dig("results", "added_group_member_ids")
    assert_equal 2, request.dig("reconciliation", "submitted_count")
    assert_equal 1, request.dig("reconciliation", "succeeded_count")
    assert_equal 1, request.dig("reconciliation", "failed_count")
    assert_equal [ "musto_employee_#{failed_employee.id}" ], request.dig("reconciliation", "failure_reference_ids")
    member_statuses = @employer.settings.fetch("vitable_care_member_sync_manifest").fetch("members").index_by { |member| member.fetch("reference_id") }
    assert_equal "synced", member_statuses.fetch("musto_employee_#{@employee.id}").fetch("status")
    assert_equal "failed", member_statuses.fetch("musto_employee_#{failed_employee.id}").fetch("status")
    assert_equal "succeeded", @employee.reload.metadata.fetch("vitable_care_member_sync_status")
    assert_equal "grpmsr_ops_123", @employee.metadata.fetch("vitable_care_member_sync_request_id")
    assert_nil @employee.metadata.fetch("vitable_care_member_sync_failure", nil)
    assert_equal "succeeded", @enrollment.reload.metadata.fetch("vitable_care_member_sync_status")
    assert_equal "failed", failed_employee.reload.metadata.fetch("vitable_care_member_sync_status")
    assert_equal "Plan is not available for this member.", failed_employee.metadata.dig("vitable_care_member_sync_failure", "reason")
    assert_equal "failed", failed_enrollment.reload.metadata.fetch("vitable_care_member_sync_status")
    submit_sync = @connection.sync_runs.where(operation: "care_member_sync_submit").recent_first.first
    assert_equal "succeeded", submit_sync.status
    assert_equal "[FILTERED]", submit_sync.stats.dig("remote_response", "data", "access_token")
    refresh_sync = @connection.sync_runs.where(operation: "care_member_sync_refresh").recent_first.first
    assert_equal "succeeded", refresh_sync.status
    assert_equal 1, refresh_sync.stats.fetch("succeeded_member_count")
    assert_equal 1, refresh_sync.stats.fetch("failed_member_count")
    assert_equal "[FILTERED]", refresh_sync.stats.dig("remote_response", "data", "refresh_token")
    assert_not_includes submit_sync.stats.to_json, "vit_at_member_sync_snapshot_secret"
    assert_not_includes refresh_sync.stats.to_json, "vit_rt_member_sync_snapshot_secret"
    assert_not_includes @employer.settings.to_json, "vit_rt_member_sync_snapshot_secret"
  ensure
    ENV[@connection.api_key_reference] = previous_key
  end

  test "verifies integration connection credentials without leaking secrets" do
    @connection.update!(status: "active", metadata: { existing: "value" })

    post verify_credentials_integration_connection_path(@connection)

    assert_redirected_to integration_connection_path(@connection)
    @connection.reload
    assert_equal "needs_credentials", @connection.status
    assert_equal "value", @connection.metadata.fetch("existing")
    assert_equal "needs_credentials", @connection.metadata.dig("last_verification", "status")
    assert_match @connection.api_key_reference, @connection.metadata.dig("last_verification", "message")
  end

  test "connection verification accepts complete wrapped access token responses" do
    response_class = Data.define(:data)
    gateway_class = Class.new do
      define_method(:initialize) { |_connection| }
      define_method(:issue_access_token) do
        response_class.new(
          data: {
            access_token: "vit_at_verify_secret",
            expires_in: 3_600,
            token_type: "Bearer"
          }
        )
      end
    end
    previous_key = ENV[@connection.api_key_reference]
    ENV[@connection.api_key_reference] = "vit_apk_test_value"

    result = Vitable::VerifyConnectionCommand.new(
      dto: Vitable::VerifyConnectionDto.new(connection_id: @connection.id),
      gateway_class:
    ).call

    assert result.success?
    @connection.reload
    assert_equal "active", @connection.status
    assert_equal "active", @connection.metadata.dig("last_verification", "status")
    assert_not_includes @connection.metadata.to_json, "vit_at_verify_secret"
  ensure
    ENV[@connection.api_key_reference] = previous_key
  end

  test "connection verification fails when token response omits access token" do
    response_class = Data.define(:expires_in, :token_type)
    gateway_class = Class.new do
      define_method(:initialize) { |_connection| }
      define_method(:issue_access_token) { response_class.new(expires_in: 3_600, token_type: "Bearer") }
    end
    previous_key = ENV[@connection.api_key_reference]
    ENV[@connection.api_key_reference] = "vit_apk_test_value"

    result = Vitable::VerifyConnectionCommand.new(
      dto: Vitable::VerifyConnectionDto.new(connection_id: @connection.id),
      gateway_class:
    ).call

    assert result.failure?
    @connection.reload
    assert_equal "failed", @connection.status
    assert_match "access token", @connection.metadata.dig("last_verification", "message")
    assert_equal "ArgumentError", @connection.metadata.dig("last_verification", "error_class")
    assert_match "access token", result.errors.to_sentence
  ensure
    ENV[@connection.api_key_reference] = previous_key
  end

  test "connection verification fails when token response omits expiry" do
    response_class = Data.define(:access_token, :token_type)
    gateway_class = Class.new do
      define_method(:initialize) { |_connection| }
      define_method(:issue_access_token) { response_class.new(access_token: "vit_at_verify_secret", token_type: "Bearer") }
    end
    previous_key = ENV[@connection.api_key_reference]
    ENV[@connection.api_key_reference] = "vit_apk_test_value"

    result = Vitable::VerifyConnectionCommand.new(
      dto: Vitable::VerifyConnectionDto.new(connection_id: @connection.id),
      gateway_class:
    ).call

    assert result.failure?
    @connection.reload
    assert_equal "failed", @connection.status
    assert_match "expires_in", @connection.metadata.dig("last_verification", "message")
    assert_match "expires_in", result.errors.to_sentence
  ensure
    ENV[@connection.api_key_reference] = previous_key
  end

  test "connection verification fails when token response type is not bearer" do
    response_class = Data.define(:access_token, :expires_in, :token_type)
    gateway_class = Class.new do
      define_method(:initialize) { |_connection| }
      define_method(:issue_access_token) do
        response_class.new(access_token: "vit_at_verify_secret", expires_in: 3_600, token_type: "Basic")
      end
    end
    previous_key = ENV[@connection.api_key_reference]
    ENV[@connection.api_key_reference] = "vit_apk_test_value"

    result = Vitable::VerifyConnectionCommand.new(
      dto: Vitable::VerifyConnectionDto.new(connection_id: @connection.id),
      gateway_class:
    ).call

    assert result.failure?
    @connection.reload
    assert_equal "failed", @connection.status
    assert_match "expected Bearer", @connection.metadata.dig("last_verification", "message")
    assert_match "expected Bearer", result.errors.to_sentence
  ensure
    ENV[@connection.api_key_reference] = previous_key
  end

  test "resolves a benefits reconciliation exception" do
    @pending_deduction.update!(amount_cents: 1_234, status: "ready")

    post resolve_benefits_reconciliation_item_path(@pending_enrollment)

    assert_redirected_to benefits_reconciliation_path
    @pending_deduction.reload
    assert_equal 0, @pending_deduction.amount_cents
    assert_equal "waiting_on_enrollment", @pending_deduction.status
  end

  test "simulates a Vitable webhook through the connection workspace" do
    assert_difference -> { WebhookEvent.count }, 1 do
      post simulate_webhook_integration_connection_path(@connection), params: {
        event_id: "wevt_ops_simulated_enrollment",
        event_name: "enrollment.accepted",
        resource_type: "enrollment",
        resource_id: "enrl_ops_primary_care"
      }
    end

    event = WebhookEvent.find_by!(event_id: "wevt_ops_simulated_enrollment")
    assert_redirected_to webhook_event_path(event)
    assert_equal @connection, event.integration_connection
    assert_equal @organization.external_id, event.organization_external_id
    assert_equal "enrollment.accepted", event.event_name
    assert_equal "needs_credentials", event.status
    assert_equal "skipped", event.metadata.dig("signature_verification", "status")
    assert_equal "enrl_ops_primary_care", event.payload.fetch("resource_id")
  end

  test "replays webhook event through command action" do
    @webhook_event.update!(status: "failed", error_message: "boom", processed_at: 1.hour.ago)

    assert_difference -> { @connection.sync_runs.where(operation: "webhook_replay").count }, 1 do
      post replay_webhook_event_path(@webhook_event)
    end

    assert_redirected_to webhook_event_path(@webhook_event)
    @webhook_event.reload
    assert_equal "needs_credentials", @webhook_event.status
    assert_nil @webhook_event.processed_at
    assert_match "not configured", @webhook_event.error_message
    sync = @connection.sync_runs.where(operation: "webhook_replay").recent_first.first
    assert_equal "needs_credentials", sync.status
    assert_equal "operations_console", sync.stats.fetch("requested_by")
    assert_equal "failed", sync.stats.fetch("previous_status")
    assert_equal "needs_credentials", sync.stats.fetch("final_status")
    assert_equal @webhook_event.event_id, sync.stats.fetch("resource_id")
    assert_match @connection.api_key_reference, sync.error_message
  end

  test "accepts an enrollment and readies payroll deductions" do
    post accept_enrollment_path(@pending_enrollment)

    assert_redirected_to enrollment_path(@pending_enrollment)
    assert_equal "accepted", @pending_enrollment.reload.status
    assert_not_nil @pending_enrollment.accepted_at
    assert_equal "ready", @pending_deduction.reload.status
    assert_equal @pending_plan.monthly_premium_cents, @pending_deduction.amount_cents
  end

  test "waives an enrollment and zeroes payroll deductions" do
    post waive_enrollment_path(@waivable_enrollment)

    assert_redirected_to enrollment_path(@waivable_enrollment)
    assert_equal "waived", @waivable_enrollment.reload.status
    assert_nil @waivable_enrollment.accepted_at
    assert_equal "waived", @waivable_deduction.reload.status
    assert_equal 0, @waivable_deduction.amount_cents
  end

  test "completes an onboarding task through the command action" do
    post complete_onboarding_task_path(@task)

    assert_redirected_to workforce_path
    assert_equal "complete", @task.reload.status
    assert_equal "in_progress", @employee.reload.onboarding_status
  end

  test "finalizes a payroll run through the command action" do
    post finalize_payroll_run_path(@payroll_run)

    assert_redirected_to payroll_run_path(@payroll_run)
    assert_equal "finalized", @payroll_run.reload.status
  end

  test "approves a time off request through the command action" do
    post approve_time_off_request_path(@time_off_request)

    assert_redirected_to compliance_path
    assert_equal "approved", @time_off_request.reload.status
    assert_not_nil @time_off_request.reviewed_at
  end

  test "resolves a compliance case through the command action" do
    post resolve_compliance_case_path(@compliance_case)

    assert_redirected_to compliance_path
    assert_equal "resolved", @compliance_case.reload.status
    assert_not_nil @compliance_case.resolved_at
  end

  test "workers comp center exposes coverage and claim DTOs" do
    detail = WorkersComp::CenterQuery.new.call

    assert_instance_of WorkersComp::CenterDto, detail
    assert_instance_of WorkersComp::MetricDto, detail.metrics.first
    assert_instance_of WorkersComp::PolicyDto, detail.policy
    assert_instance_of WorkersComp::ExposureDto, detail.exposures.first
    assert_instance_of WorkersComp::ClaimDto, detail.claims.first
    assert_instance_of WorkersComp::IssueDto, detail.issues.first
    assert detail.claims.any? { |claim| claim.id == @workers_comp_claim.id }

    get workers_comp_path

    assert_response :success
    assert_select "h1", "Workers comp coverage"
    assert_select "h2", "Audit readiness issues"
    assert_select "h2", "Open claims"
    assert_select "h2", "Class-code payroll exposure"
    assert_select "h2", "Audit packet exposure lines"
    assert_select "h2", "Audit packet holdbacks"
  end

  test "closes a workers comp claim through command action" do
    post close_workers_comp_claim_path(@workers_comp_claim), params: { closed_by: "compliance_admin", resolution: "Returned to work and carrier file closed." }

    assert_redirected_to workers_comp_path
    @workers_comp_claim.reload
    assert_equal "closed", @workers_comp_claim.status
    assert_equal "compliance_admin", @workers_comp_claim.metadata.fetch("closed_by")
    assert_equal "Returned to work and carrier file closed.", @workers_comp_claim.metadata.fetch("resolution")
    assert_not_nil @workers_comp_claim.closed_at
  end

  test "generates a workers comp audit packet through command action" do
    post generate_workers_comp_audit_packet_path, params: { requested_by: "compliance_admin" }

    assert_redirected_to workers_comp_path
    packet = @employer.reload.settings.fetch("workers_comp_audit_packet")
    assert_match(/\Aworkers_comp_audit_#{@employer.id}_#{@workers_comp_policy.id}_/, packet.fetch("packet_id"))
    assert_equal "compliance_admin", packet.fetch("requested_by")
    assert_equal @workers_comp_policy.id, packet.fetch("policy_id")
    assert_equal 1, packet.fetch("totals").fetch("exposure_count")
    assert_equal 1, packet.fetch("totals").fetch("employee_count")
    assert_equal @employee.compensation_cents, packet.fetch("totals").fetch("payroll_basis_cents")
    assert packet.fetch("totals").fetch("estimated_premium_cents").positive?
    assert_equal 1, packet.fetch("totals").fetch("claim_count")
    assert packet.fetch("totals").fetch("holdback_count").positive?

    detail = WorkersComp::CenterQuery.new.call
    assert_instance_of WorkersComp::AuditPacketDto, detail.latest_packet
    assert_instance_of WorkersComp::ExposureDto, detail.packet_lines.first
    assert_instance_of WorkersComp::AuditClaimDto, detail.packet_claims.first
    assert_instance_of WorkersComp::IssueDto, detail.packet_holdbacks.first
  end

  test "compliance notices center exposes notice DTOs" do
    detail = Compliance::NoticeCenterQuery.new.call

    assert_instance_of Compliance::NoticeCenterDto, detail
    assert_instance_of Compliance::NoticeMetricDto, detail.metrics.first
    assert_instance_of Compliance::NoticeDto, detail.notices.first
    assert_instance_of Compliance::NoticeIssueDto, detail.issues.first
    assert detail.notices.any? { |notice| notice.id == @compliance_notice.id }

    get compliance_notices_path

    assert_response :success
    assert_select "h1", "Compliance notices"
    assert_select "h2", "Notice response queue"
    assert_select "h2", "Notice holdbacks"
    assert_select "h2", "Agency notice matrix"
    assert_select "h2", "Packet notice lines"
    assert_select "h2", "Packet holdbacks"
  end

  test "acknowledges a compliance notice through command action" do
    post acknowledge_compliance_notice_path(@compliance_notice), params: { acknowledged_by: "compliance_admin" }

    assert_redirected_to compliance_notices_path
    @compliance_notice.reload
    assert_equal "in_review", @compliance_notice.status
    assert_equal "compliance_admin", @compliance_notice.metadata.fetch("acknowledged_by")
    assert_not_nil @compliance_notice.acknowledged_at
  end

  test "resolves a compliance notice through command action" do
    post resolve_compliance_notice_path(@response_ready_notice), params: { resolved_by: "compliance_admin", resolution_summary: "Submitted response package." }

    assert_redirected_to compliance_notices_path
    @response_ready_notice.reload
    assert_equal "resolved", @response_ready_notice.status
    assert_equal "Submitted response package.", @response_ready_notice.resolution_summary
    assert_equal "compliance_admin", @response_ready_notice.metadata.fetch("resolved_by")
    assert_not_nil @response_ready_notice.responded_at
    assert_not_nil @response_ready_notice.resolved_at
  end

  test "generates a compliance notice packet through command action" do
    post generate_compliance_notice_packet_path, params: { requested_by: "compliance_admin" }

    assert_redirected_to compliance_notices_path
    packet = @employer.reload.settings.fetch("compliance_notice_packet")
    assert_match(/\Acompliance_notice_#{@employer.id}_/, packet.fetch("packet_id"))
    assert_equal "compliance_admin", packet.fetch("requested_by")
    assert_equal 2, packet.fetch("totals").fetch("notice_count")
    assert_equal 2, packet.fetch("totals").fetch("open_count")
    assert_equal 1, packet.fetch("totals").fetch("ready_count")
    assert_equal @compliance_notice.amount_cents, packet.fetch("totals").fetch("amount_cents")
    assert packet.fetch("totals").fetch("holdback_count").positive?

    detail = Compliance::NoticeCenterQuery.new.call
    assert_instance_of Compliance::NoticePacketDto, detail.packet
    assert_instance_of Compliance::NoticePacketLineDto, detail.packet_lines.first
    assert_instance_of Compliance::NoticeIssueDto, detail.packet_holdbacks.first
  end

  def create_directory_manager_pair
    manager = @employer.employees.create!(
      first_name: "Mara",
      last_name: "Reed",
      email: "mara.reed.directory@example.com",
      department: @department,
      work_location: @location,
      title: "People Manager",
      compensation_cents: 130_000_00,
      onboarding_status: "complete",
      metadata: { phone: "5551234500" }
    )
    unassigned_report = @employer.employees.create!(
      first_name: "Jamie",
      last_name: "Ortiz",
      email: "jamie.ortiz.directory@example.com",
      department: @department,
      work_location: @location,
      title: "Benefits Specialist",
      compensation_cents: 88_000_00,
      onboarding_status: "complete",
      metadata: { phone: "5551234501" }
    )

    @department.update!(manager:)
    @employee.update!(manager:)

    [ manager, unassigned_report ]
  end

  def prepare_publishable_plan(plan, employee_contribution_cents: 3_900, employer_contribution_cents: nil, review_status: "draft")
    employer_contribution_cents ||= plan.monthly_premium_cents - employee_contribution_cents
    plan.update!(
      carrier: "Vitable",
      plan_year: Date.current.year + 1,
      effective_on: Date.current.next_year.beginning_of_year,
      expires_on: Date.current.next_year.end_of_year,
      employee_contribution_cents:,
      employer_contribution_cents:,
      contribution_strategy: "fixed_employer_contribution",
      eligibility_rule: "active_full_time",
      review_status:,
      published_at: review_status == "published" ? 1.hour.ago : nil,
      vitable_id: "bpln_ops_#{plan.id}"
    )
  end

  def prepare_provisioning_profile(remote_id: nil)
    @employer.update!(
      vitable_id: remote_id,
      settings: @employer.settings.to_h.merge(
        "billing_email" => "ops-benefits@example.com",
        "phone_number" => "5551239000",
        "pay_frequency" => "biweekly"
      )
    )
    @employer.work_locations.find_or_initialize_by(name: "Ops HQ").tap do |location|
      location.assign_attributes(
        address_line1: "214 Market Street",
        city: "Philadelphia",
        state: "PA",
        postal_code: "19106",
        country: "US",
        remote: false
      )
      location.save!
    end
  end

  def prepare_care_group_profile(remote_group_id: nil, remote_plan_id: "plan_care_123")
    prepare_provisioning_profile
    care_location = @employer.work_locations.find_by!(name: "Ops HQ")
    @employee.update!(work_location: care_location)
    @plan.update!(
      carrier: "Vitable",
      category: "direct_primary_care",
      vitable_id: remote_plan_id,
      metadata: @plan.metadata.to_h.merge("vitable_plan_id" => remote_plan_id)
    )
    @enrollment.update!(status: "accepted")
    return if remote_group_id.blank?

    @employer.update!(
      settings: @employer.settings.to_h.merge("vitable_care_group_id" => remote_group_id)
    )
  end

  def create_census_holdback_employee
    @employer.employees.create!(
      first_name: "Alex",
      last_name: "Missing",
      email: "alex.missing@example.com",
      department: @department,
      work_location: @location,
      title: "Benefits Analyst",
      compensation_cents: 82_000_00,
      onboarding_status: "complete"
    )
  end

  def create_census_ready_employee
    @employer.employees.create!(
      first_name: "Jordan",
      last_name: "Ready",
      email: "jordan.ready@example.com",
      department: @department,
      work_location: @location,
      title: "Benefits Coordinator",
      date_of_birth: Date.new(1989, 8, 14),
      start_on: Date.current - 1.year,
      compensation_cents: 84_000_00,
      onboarding_status: "complete",
      metadata: { phone: "5551237780" }
    )
  end

  def create_embedded_session_holdback_employee
    @employer.employees.create!(
      first_name: "Emery",
      last_name: "Remote",
      email: "emery.remote@example.com",
      department: @department,
      work_location: @location,
      title: "Enrollment Specialist",
      compensation_cents: 78_000_00,
      onboarding_status: "complete"
    ).tap do |employee|
      employee.enrollments.create!(
        benefit_plan: @pending_plan,
        status: "pending",
        effective_on: Date.current.next_month.beginning_of_month
      )
    end
  end

  def create_care_member_holdback_employee
    care_location = @employer.work_locations.find_by!(name: "Ops HQ")
    @employer.employees.create!(
      first_name: "Riley",
      last_name: "Planless",
      email: "riley.planless@example.com",
      department: @department,
      work_location: care_location,
      title: "Care Coordinator",
      date_of_birth: Date.new(1992, 4, 7),
      start_on: Date.current - 1.year,
      compensation_cents: 83_000_00,
      onboarding_status: "complete",
      metadata: { phone: "5551237788" }
    ).tap do |employee|
      employee.enrollments.create!(
        benefit_plan: @pending_plan,
        status: "accepted",
        effective_on: Date.current.beginning_of_month
      )
    end
  end
end
