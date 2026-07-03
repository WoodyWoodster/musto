require "test_helper"

class EmployeeLifecycleEventTest < ActiveSupport::TestCase
  setup do
    organization = Organization.create!(name: "Lifecycle Org", external_id: "lifecycle_org")
    employer = organization.employers.create!(name: "Lifecycle Employer", status: "active")
    @employee = employer.employees.create!(
      first_name: "Casey",
      last_name: "Ng",
      email: "casey-lifecycle@example.com",
      compensation_cents: 80_000_00
    )
  end

  test "approves lifecycle event with reviewer metadata" do
    event = @employee.employee_lifecycle_events.create!(
      event_type: "compensation_change",
      effective_on: Date.current + 14.days,
      summary: "Base compensation adjustment",
      metadata: { payroll_impact: "pay_rate_update" }
    )

    event.approve!(reviewed_by: "ops_console")

    assert_equal "approved", event.status
    assert_equal "ops_console", event.metadata.fetch("reviewed_by")
    assert_not_nil event.reviewed_at
  end

  test "queues approved lifecycle event for local sync batch" do
    event = @employee.employee_lifecycle_events.create!(
      event_type: "termination",
      effective_on: Date.current + 30.days,
      summary: "Planned separation",
      status: "approved"
    )

    event.queue_for_sync!(batch_id: "lifecycle_sync_1_123")

    assert_equal "sync_queued", event.status
    assert_equal "lifecycle_sync_1_123", event.metadata.fetch("sync_batch_id")
  end
end
