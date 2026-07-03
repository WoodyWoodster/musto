require "test_helper"

class PerformanceCycleTest < ActiveSupport::TestCase
  setup do
    organization = Organization.create!(name: "Performance Org", external_id: "performance_org")
    @employer = organization.employers.create!(name: "Performance Employer", status: "active")
  end

  test "requires period end on or after period start" do
    cycle = @employer.performance_cycles.build(
      name: "Invalid cycle",
      period_start_on: Date.current,
      period_end_on: Date.current - 1.day,
      due_on: Date.current + 14.days
    )

    assert_not cycle.valid?
    assert_includes cycle.errors[:period_end_on], "must be on or after the period start"
  end

  test "launches cycle with audit metadata" do
    cycle = @employer.performance_cycles.create!(
      name: "Q3 Review",
      period_start_on: Date.current.beginning_of_quarter,
      period_end_on: Date.current.end_of_quarter,
      due_on: Date.current.end_of_quarter + 14.days
    )

    cycle.launch!(requested_by: "people_ops")

    assert cycle.active?
    assert_equal "people_ops", cycle.metadata.fetch("launched_by")
    assert_not_nil cycle.launched_at
  end
end
