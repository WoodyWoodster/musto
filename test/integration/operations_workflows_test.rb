require "test_helper"

class OperationsWorkflowsTest < ActionDispatch::IntegrationTest
  setup do
    @organization = Organization.create!(name: "Ops Platform", external_id: "org_ops")
    @employer = @organization.employers.create!(name: "Ops Employer", status: "active")
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
    @policy = @employer.time_off_policies.create!(name: "PTO", annual_hours: 120)
    @time_off_request = @employee.time_off_requests.create!(time_off_policy: @policy, starts_on: Date.current + 1.day, ends_on: Date.current + 2.days, hours: 16)
    @payroll_run = @employer.payroll_runs.create!(period_start_on: Date.current.beginning_of_month, period_end_on: Date.current.end_of_month, pay_date: Date.current.end_of_month, gross_pay_cents: 9_500_00, status: "estimated")
    @payroll_run.payroll_deductions.create!(employee: @employee, enrollment: @enrollment, code: "VITABLE_BENEFITS", amount_cents: 9_900, status: "ready")
    @pending_deduction = @payroll_run.payroll_deductions.create!(employee: @employee, enrollment: @pending_enrollment, code: "VITABLE_DENTAL", amount_cents: 0, status: "waiting_on_enrollment")
    @waivable_deduction = @payroll_run.payroll_deductions.create!(employee: @employee, enrollment: @waivable_enrollment, code: "VITABLE_VISION", amount_cents: 0, status: "waiting_on_enrollment")
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
      workforce_path,
      payroll_path,
      payroll_run_path(@payroll_run),
      benefits_path,
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
    workforce = Operations::WorkforceQuery.new.call
    payroll = Operations::PayrollQuery.new.call
    benefits = Operations::BenefitsQuery.new.call
    compliance = Operations::ComplianceQuery.new.call
    integrations = Operations::IntegrationsQuery.new.call

    assert_instance_of Employers::EmployerSummaryDto, dashboard.fetch(:employers).first
    assert_instance_of Dashboard::IntegrationHealthDto, dashboard.fetch(:integration_health)
    assert_instance_of Operations::WorkforceEmployeeDto, workforce.fetch(:employees).first
    assert_instance_of Operations::PayrollRunDto, payroll.fetch(:payroll_runs).first
    assert_instance_of Operations::BenefitPlanDto, benefits.fetch(:benefit_plans).first
    assert_instance_of Operations::ComplianceCaseDto, compliance.fetch(:cases).first
    assert_instance_of Operations::IntegrationConnectionDto, integrations.fetch(:connections).first
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
    assert_equal @sync_run.id, detail.sync_runs.first.id
    assert_equal @request_log.id, detail.request_logs.first.id

    get integration_connection_path(@connection)

    assert_response :success
    assert_select "h1", "#{@organization.name} Vitable connection"
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
    assert_equal "complete", @employee.reload.onboarding_status
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
