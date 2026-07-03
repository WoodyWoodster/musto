require "test_helper"

class TimeOffAccrualTest < ActiveSupport::TestCase
  setup do
    organization = Organization.create!(name: "Accrual Org", external_id: "org_accrual")
    @employer = organization.employers.create!(name: "Accrual Employer", legal_name: "Accrual Employer LLC", ein: "12-0000000", status: "active")
    @policy = @employer.time_off_policies.create!(name: "PTO", annual_hours: 120, carryover_hours: 16)
    @employee = @employer.employees.create!(
      first_name: "Ari",
      last_name: "Ledger",
      email: "ari.ledger@example.com",
      compensation_cents: 90_000_00,
      onboarding_status: "complete"
    )
  end

  test "requires nonzero accrual hours" do
    accrual = build_accrual(hours: 0)

    assert_not accrual.valid?
    assert_includes accrual.errors[:hours], "must be other than 0"
  end

  test "requires period end on or after period start" do
    accrual = build_accrual(period_start_on: Date.current.end_of_month, period_end_on: Date.current.beginning_of_month)

    assert_not accrual.valid?
    assert_includes accrual.errors[:period_end_on], "must be on or after period start"
  end

  private

  def build_accrual(attributes = {})
    @employee.time_off_accruals.build({
      time_off_policy: @policy,
      accrual_type: "monthly_accrual",
      hours: 10,
      period_start_on: Date.current.beginning_of_month,
      period_end_on: Date.current.end_of_month,
      effective_on: Date.current.end_of_month,
      source: "system",
      status: "pending"
    }.merge(attributes))
  end
end
