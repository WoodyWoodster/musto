require "test_helper"

class PayrollApprovalStepTest < ActiveSupport::TestCase
  setup do
    organization = Organization.create!(name: "Approval Org", external_id: "approval_org")
    employer = organization.employers.create!(name: "Approval Employer", status: "active")
    @run = employer.payroll_runs.create!(period_start_on: Date.current.beginning_of_month, period_end_on: Date.current.end_of_month, pay_date: Date.current.end_of_month, gross_pay_cents: 10_000_00)
  end

  test "completes a payroll approval step with audit metadata" do
    step = @run.payroll_approval_steps.create!(key: "time_review", title: "Approve time", owner: "Managers", due_at: 1.day.from_now, position: 1)

    step.complete!(completed_by: "payroll_admin")

    assert step.completed?
    assert_equal "payroll_admin", step.completed_by
    assert_equal "payroll_admin", step.metadata.fetch("completed_by")
    assert_not_nil step.completed_at
  end

  test "tracks overdue incomplete controls" do
    step = @run.payroll_approval_steps.create!(key: "funding_source", title: "Confirm funding", owner: "Finance", due_at: 1.hour.ago, position: 2)

    assert step.overdue?
    assert step.completable?
  end
end
