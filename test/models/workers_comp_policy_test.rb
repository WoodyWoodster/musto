require "test_helper"

class WorkersCompPolicyTest < ActiveSupport::TestCase
  setup do
    organization = Organization.create!(name: "Workers Comp Org", external_id: "workers_comp_org")
    @employer = organization.employers.create!(name: "Workers Comp Employer", status: "active")
  end

  test "requires coverage to end after it starts" do
    policy = @employer.workers_comp_policies.build(
      carrier: "Carrier",
      policy_number: "WC-BAD-DATES",
      status: "active",
      coverage_start_on: Date.current,
      coverage_end_on: Date.current - 1.day,
      renewal_due_on: Date.current + 30.days
    )

    assert_not policy.valid?
    assert_includes policy.errors[:coverage_end_on], "must be on or after the coverage start date"
  end

  test "reports active coverage and renewal status" do
    policy = @employer.workers_comp_policies.create!(
      carrier: "Carrier",
      policy_number: "WC-ACTIVE",
      status: "active",
      coverage_start_on: Date.current - 1.month,
      coverage_end_on: Date.current + 6.months,
      renewal_due_on: Date.current + 30.days
    )

    assert policy.coverage_active?
    assert policy.renewal_due?
  end
end
