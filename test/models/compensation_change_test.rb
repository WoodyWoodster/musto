require "test_helper"

class CompensationChangeTest < ActiveSupport::TestCase
  setup do
    organization = Organization.create!(name: "Comp Change Org", external_id: "comp_change_org")
    @employer = organization.employers.create!(name: "Comp Change Employer", status: "active")
    @employee = @employer.employees.create!(
      first_name: "Casey",
      last_name: "Ng",
      email: "casey.comp.change@example.com",
      employment_status: "active",
      pay_type: "salary",
      onboarding_status: "complete",
      compensation_cents: 100_000_00
    )
  end

  test "classifies base pay and one-time compensation changes" do
    base_change = @employer.compensation_changes.create!(
      employee: @employee,
      change_type: "merit_increase",
      status: "approved",
      reason: "Annual merit cycle",
      current_compensation_cents: 100_000_00,
      proposed_compensation_cents: 105_000_00,
      delta_cents: 5_000_00,
      effective_on: Date.current
    )
    bonus_change = @employer.compensation_changes.create!(
      employee: @employee,
      change_type: "one_time_bonus",
      status: "approved",
      reason: "Implementation bonus",
      current_compensation_cents: 100_000_00,
      proposed_compensation_cents: 100_000_00,
      delta_cents: 1_000_00,
      effective_on: Date.current
    )

    assert base_change.base_pay_change?
    assert_not base_change.one_time_change?
    assert bonus_change.one_time_change?
  end

  test "requires employee to belong to the employer" do
    other_employer = Organization.create!(name: "Other Org", external_id: "other_comp_org").employers.create!(name: "Other Employer", status: "active")
    change = other_employer.compensation_changes.build(
      employee: @employee,
      change_type: "promotion",
      status: "submitted",
      reason: "Invalid cross-employer change",
      current_compensation_cents: 100_000_00,
      proposed_compensation_cents: 110_000_00,
      delta_cents: 10_000_00,
      effective_on: Date.current
    )

    assert_not change.valid?
    assert_includes change.errors[:employee], "must belong to employer"
  end
end
