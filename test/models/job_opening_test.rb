require "test_helper"

class JobOpeningTest < ActiveSupport::TestCase
  setup do
    organization = Organization.create!(name: "Hiring Org", external_id: "hiring_org")
    @employer = organization.employers.create!(name: "Hiring Employer", status: "active")
  end

  test "requires a valid compensation range" do
    opening = @employer.job_openings.build(
      title: "Payroll Lead",
      code: "PAY-LEAD",
      compensation_min_cents: 120_000_00,
      compensation_max_cents: 110_000_00
    )

    assert_not opening.valid?
    assert_includes opening.errors[:compensation_max_cents], "must be greater than or equal to the minimum"
  end

  test "tracks open role state" do
    opening = @employer.job_openings.create!(
      title: "Benefits Manager",
      code: "BEN-MGR",
      status: "open",
      compensation_min_cents: 90_000_00,
      compensation_max_cents: 110_000_00
    )

    assert opening.open?
    assert_includes @employer.job_openings.open_roles, opening
  end
end
