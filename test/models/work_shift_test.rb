require "test_helper"

class WorkShiftTest < ActiveSupport::TestCase
  setup do
    organization = Organization.create!(name: "Schedule Org", external_id: "schedule_org")
    @employer = organization.employers.create!(name: "Schedule Employer", status: "active")
    @employee = @employer.employees.create!(first_name: "Casey", last_name: "Ng", email: "casey.shift@example.com", compensation_cents: 62_400_00)
  end

  test "calculates net minutes and labor cost" do
    shift = @employer.work_shifts.create!(
      employee: @employee,
      role: "Cafe lead",
      starts_at: Time.current.change(hour: 8),
      ends_at: Time.current.change(hour: 16),
      break_minutes: 30,
      hourly_rate_cents: 3_000,
      status: "published"
    )

    assert_equal 450, shift.net_minutes
    assert_equal 22_500, shift.labor_cost_cents
    assert shift.payable?
  end

  test "requires end after start" do
    shift = @employer.work_shifts.build(
      employee: @employee,
      role: "Invalid shift",
      starts_at: Time.current.change(hour: 16),
      ends_at: Time.current.change(hour: 8)
    )

    assert_not shift.valid?
    assert_includes shift.errors[:ends_at], "must be after the shift start"
  end
end
