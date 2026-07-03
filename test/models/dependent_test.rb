require "test_helper"

class DependentTest < ActiveSupport::TestCase
  setup do
    organization = Organization.create!(name: "Dependent Org", external_id: "dependent_org")
    employer = organization.employers.create!(name: "Dependent Employer", status: "active")
    @employee = employer.employees.create!(
      first_name: "Casey",
      last_name: "Ng",
      email: "casey-dependent@example.com",
      compensation_cents: 80_000_00
    )
  end

  test "reports eligible only when enrolled and eligible" do
    dependent = @employee.dependents.create!(
      first_name: "Harper",
      last_name: "Ng",
      relationship: "spouse",
      enrollment_status: "enrolled",
      eligibility_status: "eligible"
    )

    assert dependent.enrolled?
    assert dependent.eligible?
    assert_equal "Harper Ng", dependent.full_name
  end

  test "does not report pending dependent as eligible" do
    dependent = @employee.dependents.create!(
      first_name: "Rowan",
      last_name: "Ng",
      relationship: "child",
      enrollment_status: "pending",
      eligibility_status: "needs_review"
    )

    assert_not dependent.enrolled?
    assert_not dependent.eligible?
  end
end
