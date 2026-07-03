require "test_helper"

class DependentVerificationTest < ActiveSupport::TestCase
  setup do
    organization = Organization.create!(name: "Dependent Verification Org", external_id: "dependent_verification_org")
    employer = organization.employers.create!(name: "Dependent Verification Employer", status: "active")
    employee = employer.employees.create!(
      first_name: "Casey",
      last_name: "Ng",
      email: "casey-dependent-verification@example.com",
      compensation_cents: 80_000_00
    )
    @dependent = employee.dependents.create!(
      first_name: "Harper",
      last_name: "Ng",
      relationship: "spouse",
      enrollment_status: "pending",
      eligibility_status: "needs_review"
    )
  end

  test "requires due date to be on or after request date" do
    verification = @dependent.dependent_verifications.build(
      verification_type: "relationship_proof",
      status: "requested",
      requested_on: Date.current,
      due_on: Date.current - 1.day
    )

    assert_not verification.valid?
    assert_includes verification.errors[:due_on], "must be on or after requested on"
  end
end
