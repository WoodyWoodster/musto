require "test_helper"

class TimeEntryTest < ActiveSupport::TestCase
  setup do
    organization = Organization.create!(name: "Time Org", external_id: "time_org")
    employer = organization.employers.create!(name: "Time Employer", status: "active")
    @employee = employer.employees.create!(
      first_name: "Alex",
      last_name: "Taylor",
      email: "alex-time@example.com",
      compensation_cents: 80_000_00
    )
  end

  test "calculates payable minutes after breaks" do
    start_at = Time.zone.local(2026, 7, 3, 9, 0, 0)
    entry = @employee.time_entries.create!(
      work_date: Date.current,
      clock_in_at: start_at,
      clock_out_at: start_at + 8.hours,
      break_minutes: 30
    )

    assert_equal 450, entry.duration_minutes
    assert_equal 7.5, entry.payable_hours
  end

  test "requires clock out after clock in" do
    start_at = Time.zone.local(2026, 7, 3, 9, 0, 0)
    entry = @employee.time_entries.build(
      work_date: Date.current,
      clock_in_at: start_at,
      clock_out_at: start_at,
      break_minutes: 0
    )

    assert_not entry.valid?
    assert_includes entry.errors[:clock_out_at], "must be after clock in"
  end
end
