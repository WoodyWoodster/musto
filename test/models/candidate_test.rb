require "test_helper"

class CandidateTest < ActiveSupport::TestCase
  setup do
    organization = Organization.create!(name: "Candidate Org", external_id: "candidate_org")
    employer = organization.employers.create!(name: "Candidate Employer", status: "active")
    @opening = employer.job_openings.create!(
      title: "Operations Manager",
      code: "OPS-MGR",
      compensation_min_cents: 95_000_00,
      compensation_max_cents: 115_000_00
    )
  end

  test "exposes pipeline state helpers" do
    candidate = @opening.candidates.create!(
      first_name: "Nia",
      last_name: "Okafor",
      email: "nia@example.com",
      source: "referral",
      stage: "interview",
      applied_on: Date.current,
      score: 92,
      compensation_cents: 105_000_00
    )

    assert_equal "Nia Okafor", candidate.full_name
    assert candidate.offerable?
    assert_not candidate.accepted?
    assert_not candidate.inactive?
  end

  test "treats hired rejected and withdrawn candidates as inactive" do
    candidate = @opening.candidates.build(
      first_name: "Miles",
      last_name: "Sato",
      email: "miles@example.com",
      source: "direct",
      stage: "hired",
      applied_on: Date.current,
      compensation_cents: 100_000_00
    )

    assert candidate.inactive?
    assert_not candidate.offerable?
  end
end
