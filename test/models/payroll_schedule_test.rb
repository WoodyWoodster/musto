require "test_helper"

class PayrollScheduleTest < ActiveSupport::TestCase
  setup do
    organization = Organization.create!(name: "Schedule Org", external_id: "schedule_org")
    @employer = organization.employers.create!(name: "Schedule Employer", status: "active")
  end

  test "requires a valid pay cycle window" do
    schedule = @employer.payroll_schedules.build(
      name: "Primary",
      cadence: "biweekly",
      period_anchor_on: Date.current,
      next_period_start_on: Date.current + 14.days,
      next_period_end_on: Date.current,
      next_pay_date: Date.current + 21.days,
      approval_deadline_at: 3.days.from_now,
      funding_deadline_at: 4.days.from_now
    )

    assert_not schedule.valid?
    assert_includes schedule.errors[:next_period_end_on], "must be on or after the next period start date"
  end

  test "calculates days until payday" do
    schedule = @employer.payroll_schedules.create!(
      name: "Primary",
      cadence: "biweekly",
      period_anchor_on: Date.current,
      next_period_start_on: Date.current,
      next_period_end_on: Date.current + 13.days,
      next_pay_date: Date.current + 15.days,
      approval_deadline_at: 3.days.from_now,
      funding_deadline_at: 4.days.from_now
    )

    assert_equal 15, schedule.days_until_payday
    assert schedule.active?
  end
end
