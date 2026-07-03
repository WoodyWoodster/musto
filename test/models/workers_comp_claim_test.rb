require "test_helper"

class WorkersCompClaimTest < ActiveSupport::TestCase
  setup do
    organization = Organization.create!(name: "Workers Claim Org", external_id: "workers_claim_org")
    @employer = organization.employers.create!(name: "Workers Claim Employer", status: "active")
    @employee = @employer.employees.create!(first_name: "Casey", last_name: "Claim", email: "casey.claim@example.com", compensation_cents: 75_000_00)
    @policy = @employer.workers_comp_policies.create!(
      carrier: "Carrier",
      policy_number: "WC-CLAIM",
      status: "active",
      coverage_start_on: Date.current.beginning_of_year,
      coverage_end_on: Date.current.end_of_year,
      renewal_due_on: Date.current + 45.days
    )
  end

  test "requires employee and policy to belong to claim employer" do
    other_employer = Organization.create!(name: "Other Workers Org", external_id: "other_workers_claim_org").employers.create!(name: "Other Workers Employer", status: "active")
    claim = other_employer.workers_comp_claims.build(
      employee: @employee,
      workers_comp_policy: @policy,
      incident_on: Date.current,
      reported_on: Date.current,
      status: "reported",
      severity: "medical_only",
      description: "Cross-employer claim should be invalid."
    )

    assert_not claim.valid?
    assert_includes claim.errors[:employee], "must belong to claim employer"
    assert_includes claim.errors[:workers_comp_policy], "must belong to claim employer"
  end

  test "closes an open claim with audit metadata" do
    claim = @policy.workers_comp_claims.create!(
      employer: @employer,
      employee: @employee,
      claim_number: "WC-CLOSE-1",
      incident_on: Date.current - 2.days,
      reported_on: Date.current - 1.day,
      status: "accepted",
      severity: "lost_time",
      description: "Lost time claim."
    )

    claim.close!(closed_by: "compliance_admin", resolution: "Returned to work")

    assert_equal "closed", claim.status
    assert_equal "compliance_admin", claim.metadata.fetch("closed_by")
    assert_equal "Returned to work", claim.metadata.fetch("resolution")
    assert_not_nil claim.closed_at
  end
end
