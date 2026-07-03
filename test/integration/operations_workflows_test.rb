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
    @employee = @employer.employees.create!(
      first_name: "Casey",
      last_name: "Ng",
      email: "casey@example.com",
      department: @department,
      work_location: @location,
      title: "People Ops Lead",
      compensation_cents: 115_000_00,
      onboarding_status: "in_progress"
    )
    @plan = @employer.benefit_plans.create!(name: "Primary Care", category: "direct_primary_care", monthly_premium_cents: 9_900)
    @enrollment = @employee.enrollments.create!(benefit_plan: @plan, status: "accepted", effective_on: Date.current)
    @pending_plan = @employer.benefit_plans.create!(name: "Dental", category: "dental", monthly_premium_cents: 4_500)
    @pending_enrollment = @employee.enrollments.create!(benefit_plan: @pending_plan, status: "pending", effective_on: Date.current.next_month.beginning_of_month)
    @waivable_plan = @employer.benefit_plans.create!(name: "Vision", category: "vision", monthly_premium_cents: 2_500)
    @waivable_enrollment = @employee.enrollments.create!(benefit_plan: @waivable_plan, status: "pending", effective_on: Date.current.next_month.beginning_of_month)
    @task = @employee.onboarding_tasks.create!(title: "Confirm payroll setup", category: "payroll", due_on: Date.current)
    @pending_document = @employee.employee_documents.create!(title: "Benefits disclosure", document_type: "benefits", status: "pending", expires_on: Date.current + 30.days)
    @complete_document = @employee.employee_documents.create!(title: "Form W-4", document_type: "tax", status: "complete", issued_on: Date.current)
    @policy = @employer.time_off_policies.create!(name: "PTO", annual_hours: 120)
    @time_off_request = @employee.time_off_requests.create!(time_off_policy: @policy, starts_on: Date.current + 1.day, ends_on: Date.current + 2.days, hours: 16)
    @sick_policy = @employer.time_off_policies.create!(name: "Sick Leave", accrual_method: "state_accrual", annual_hours: 56, carryover_hours: 16)
    @approved_time_off_request = @employee.time_off_requests.create!(time_off_policy: @sick_policy, starts_on: Date.current + 10.days, ends_on: Date.current + 10.days, hours: 8, status: "approved", reviewed_at: 1.day.ago)
    @payroll_run = @employer.payroll_runs.create!(period_start_on: Date.current.beginning_of_month, period_end_on: Date.current.end_of_month, pay_date: Date.current.end_of_month, gross_pay_cents: 9_500_00, status: "estimated")
    @payroll_run.payroll_deductions.create!(employee: @employee, enrollment: @enrollment, code: "VITABLE_BENEFITS", amount_cents: 9_900, status: "ready")
    @pending_deduction = @payroll_run.payroll_deductions.create!(employee: @employee, enrollment: @pending_enrollment, code: "VITABLE_DENTAL", amount_cents: 0, status: "waiting_on_enrollment")
    @waivable_deduction = @payroll_run.payroll_deductions.create!(employee: @employee, enrollment: @waivable_enrollment, code: "VITABLE_VISION", amount_cents: 0, status: "waiting_on_enrollment")
    @payroll_adjustment = @payroll_run.payroll_adjustments.create!(employee: @employee, adjustment_type: "bonus", description: "Quarterly performance bonus", amount_cents: 1_500_00, taxable: true)
    time_start = @payroll_run.period_start_on.in_time_zone.change(hour: 9, min: 0)
    @approved_time_entry = @employee.time_entries.create!(work_date: @payroll_run.period_start_on, clock_in_at: time_start, clock_out_at: time_start + 8.hours, break_minutes: 30, source: "web", status: "approved", approved_at: 1.hour.ago, reviewed_at: 1.hour.ago, notes: "Regular shift")
    @submitted_time_entry = @employee.time_entries.create!(work_date: @payroll_run.period_start_on + 1.day, clock_in_at: time_start + 1.day, clock_out_at: time_start + 1.day + 9.hours, break_minutes: 45, source: "mobile", status: "submitted", notes: "Needs manager review")
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
    @compliance_case = @employer.compliance_cases.create!(employee: @employee, kind: "i9_reverification", severity: "high", due_on: Date.current + 5.days)
    @connection = @organization.integration_connections.create!(provider: "vitable", environment: "production")
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
      event_id: "wevt_ops_employee_created",
      organization_external_id: @organization.external_id,
      event_name: "employee.created",
      resource_type: "employee",
      resource_id: "empl_ops_123",
      occurred_at: Time.current,
      status: "needs_credentials",
      payload: {
        event_id: "wevt_ops_employee_created",
        organization_id: @organization.external_id,
        event_name: "employee.created",
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
      onboarding_path,
      time_off_path,
      timesheets_path,
      contractors_path,
      compensation_path,
      taxes_path,
      reports_path,
      payroll_path,
      payroll_run_path(@payroll_run),
      payroll_run_benefits_export_path(@payroll_run),
      benefits_path,
      benefits_reconciliation_path,
      enrollment_path(@pending_enrollment),
      compliance_path,
      integrations_path,
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
    payroll = Operations::PayrollQuery.new.call
    onboarding = Onboarding::CommandCenterQuery.new.call
    time_off = TimeOff::CommandCenterQuery.new.call
    timesheets = TimeTracking::CenterQuery.new.call
    contractors = Contractors::CenterQuery.new.call
    compensation = Compensation::CenterQuery.new.call
    taxes = Taxes::CenterQuery.new.call
    reports = Reports::CenterQuery.new.call
    benefits = Operations::BenefitsQuery.new.call
    reconciliation = Benefits::ReconciliationQuery.new.call
    compliance = Operations::ComplianceQuery.new.call
    integrations = Operations::IntegrationsQuery.new.call

    assert_instance_of Employers::EmployerSummaryDto, dashboard.fetch(:employers).first
    assert_instance_of Dashboard::IntegrationHealthDto, dashboard.fetch(:integration_health)
    assert_instance_of Company::SetupDetailDto, company
    assert_instance_of Company::SetupStepDto, company.steps.first
    assert_instance_of Company::MetricDto, company.metrics.first
    assert_instance_of Operations::WorkforceEmployeeDto, workforce.fetch(:employees).first
    assert_instance_of Operations::PayrollRunDto, payroll.fetch(:payroll_runs).first
    assert_instance_of Onboarding::CommandCenterDto, onboarding
    assert_instance_of Onboarding::EmployeeReadinessDto, onboarding.readiness.first
    assert_instance_of Onboarding::TaskDto, onboarding.tasks.first
    assert_instance_of Onboarding::DocumentDto, onboarding.documents.first
    assert_instance_of Onboarding::LaneDto, onboarding.lanes.first
    assert_instance_of TimeOff::CommandCenterDto, time_off
    assert_instance_of TimeOff::RequestDto, time_off.requests.first
    assert_instance_of TimeOff::PolicyDto, time_off.policies.first
    assert_instance_of TimeOff::EmployeeBalanceDto, time_off.balances.first
    assert_instance_of TimeTracking::CenterDto, timesheets
    assert_instance_of TimeTracking::EntryDto, timesheets.entries.first
    assert_instance_of TimeTracking::EmployeeSummaryDto, timesheets.employees.first
    assert_instance_of TimeTracking::DepartmentSummaryDto, timesheets.departments.first
    assert_instance_of TimeTracking::ExceptionDto, timesheets.exceptions.first
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
    assert_instance_of Taxes::CenterDto, taxes
    assert_instance_of Taxes::AgencyAccountDto, taxes.agency_accounts.first
    assert_instance_of Taxes::PayrollLiabilityDto, taxes.liabilities.first
    assert_instance_of Taxes::FilingCalendarItemDto, taxes.filing_calendar.first
    assert_instance_of Taxes::JurisdictionExposureDto, taxes.jurisdictions.first
    assert_instance_of Reports::CenterDto, reports
    assert_instance_of Reports::MetricDto, reports.metrics.first
    assert_instance_of Reports::ReportCardDto, reports.report_cards.first
    assert_instance_of Operations::BenefitPlanDto, benefits.fetch(:benefit_plans).first
    assert_instance_of Benefits::ReconciliationDetailDto, reconciliation
    assert_instance_of Operations::ComplianceCaseDto, compliance.fetch(:cases).first
    assert_instance_of Operations::IntegrationConnectionDto, integrations.fetch(:connections).first
  end

  test "reports command center exposes finance and risk DTOs" do
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
    assert_select "h1", "Reports command center"
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

  test "onboarding command center exposes readiness and review DTOs" do
    detail = Onboarding::CommandCenterQuery.new.call

    assert_instance_of Onboarding::CommandCenterDto, detail
    assert_instance_of Onboarding::CommandMetricDto, detail.metrics.first
    assert_instance_of Onboarding::EmployeeReadinessDto, detail.readiness.first
    assert_instance_of Onboarding::TaskDto, detail.tasks.first
    assert_instance_of Onboarding::DocumentDto, detail.documents.first
    assert detail.attention_documents.any? { |document| document.id == @pending_document.id }

    get onboarding_path

    assert_response :success
    assert_select "h1", "Onboarding command center"
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
  end

  test "time off command center exposes policies balances and calendar DTOs" do
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
    assert_select "h1", "Time off command center"
    assert_select "h2", "Request review"
    assert_select "h2", "Employee balances"
    assert_select "h2", "Policy utilization"
    assert_select "h2", "Upcoming leave calendar"
  end

  test "approves a time off request from the time off command center" do
    post approve_time_off_request_path(@time_off_request), params: { return_to: "time_off" }

    assert_redirected_to time_off_path
    @time_off_request.reload
    assert_equal "approved", @time_off_request.status
    assert_equal "time_off_command_center", @time_off_request.metadata.fetch("reviewed_from")
    assert_equal "approved", @time_off_request.metadata.fetch("review_decision")
    assert_not_nil @time_off_request.reviewed_at
  end

  test "timesheets command center exposes approval and export DTOs" do
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
    assert_select "h1", "Timesheets command center"
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
    assert_equal 1, batch.fetch("totals").fetch("payment_count")
    assert_equal 1, batch.fetch("totals").fetch("contractor_count")
    assert_equal 1, batch.fetch("totals").fetch("holdback_count")
    assert_equal @contractor_payment.amount_cents, batch.fetch("totals").fetch("total_cents")

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

    get webhook_event_path(@webhook_event)

    assert_response :success
    assert_select "h1", @webhook_event.event_name
    assert_select "h2", "Replay preflight"
    assert_select "h2", "Stored payload"
    assert_select "h2", "Event timeline"
    assert_select "h2", "Sync attempts"
  end

  test "integration connection workspace exposes credential and coverage DTOs" do
    detail = Vitable::ConnectionDetailQuery.new.call(@connection.id)

    assert_instance_of Vitable::ConnectionDetailDto, detail
    assert_instance_of Vitable::ConnectionMetricDto, detail.metrics.first
    assert_instance_of Vitable::ConnectionHealthCheckDto, detail.health_checks.first
    assert_instance_of Vitable::EndpointCoverageDto, detail.endpoint_coverage.first
    assert_instance_of Vitable::ConnectionTimelineItemDto, detail.timeline.first
    assert_instance_of Vitable::WebhookSimulatorDto, detail.simulator
    assert_instance_of Vitable::WebhookSimulationEventOptionDto, detail.simulator.event_options.first
    assert_equal @sync_run.id, detail.sync_runs.first.id
    assert_equal @request_log.id, detail.request_logs.first.id

    get integration_connection_path(@connection)

    assert_response :success
    assert_select "h1", "#{@organization.name} Vitable connection"
    assert_select "h2", "Sandbox webhook composer"
    assert_select "h2", "Readiness checks"
    assert_select "h2", "Resource coverage"
    assert_select "h2", "Connection timeline"
    assert_select "h2", "Webhook queue"
    assert_select "h2", "API request trail"
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
        event_id: "wevt_ops_simulated_benefit_plan",
        event_name: "benefit_plan.updated",
        resource_type: "benefit_plan",
        resource_id: "bpln_ops_primary_care"
      }
    end

    event = WebhookEvent.find_by!(event_id: "wevt_ops_simulated_benefit_plan")
    assert_redirected_to webhook_event_path(event)
    assert_equal @connection, event.integration_connection
    assert_equal @organization.external_id, event.organization_external_id
    assert_equal "benefit_plan.updated", event.event_name
    assert_equal "needs_credentials", event.status
    assert_equal "bpln_ops_primary_care", event.payload.fetch("resource_id")
  end

  test "replays webhook event through command action" do
    @webhook_event.update!(status: "failed", error_message: "boom", processed_at: 1.hour.ago)

    post replay_webhook_event_path(@webhook_event)

    assert_redirected_to webhook_event_path(@webhook_event)
    @webhook_event.reload
    assert_equal "needs_credentials", @webhook_event.status
    assert_nil @webhook_event.processed_at
    assert_match "not configured", @webhook_event.error_message
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
end
