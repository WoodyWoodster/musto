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
    @employee.enrollments.create!(benefit_plan: @plan, status: "accepted", effective_on: Date.current)
    @task = @employee.onboarding_tasks.create!(title: "Confirm payroll setup", category: "payroll", due_on: Date.current)
    @policy = @employer.time_off_policies.create!(name: "PTO", annual_hours: 120)
    @time_off_request = @employee.time_off_requests.create!(time_off_policy: @policy, starts_on: Date.current + 1.day, ends_on: Date.current + 2.days, hours: 16)
    @payroll_run = @employer.payroll_runs.create!(period_start_on: Date.current.beginning_of_month, period_end_on: Date.current.end_of_month, pay_date: Date.current.end_of_month, gross_pay_cents: 9_500_00, status: "estimated")
    @payroll_run.payroll_deductions.create!(employee: @employee, enrollment: @employee.enrollments.first, code: "VITABLE_BENEFITS", amount_cents: 9_900, status: "ready")
    @compliance_case = @employer.compliance_cases.create!(employee: @employee, kind: "i9_reverification", severity: "high", due_on: Date.current + 5.days)
    @organization.integration_connections.create!(provider: "vitable", environment: "production")
  end

  test "renders the expanded operations pages" do
    [ root_path, workforce_path, payroll_path, benefits_path, compliance_path, integrations_path ].each do |path|
      get path
      assert_response :success
    end
  end

  test "completes an onboarding task through the command action" do
    post complete_onboarding_task_path(@task)

    assert_redirected_to workforce_path
    assert_equal "complete", @task.reload.status
    assert_equal "complete", @employee.reload.onboarding_status
  end

  test "finalizes a payroll run through the command action" do
    post finalize_payroll_run_path(@payroll_run)

    assert_redirected_to payroll_path
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
