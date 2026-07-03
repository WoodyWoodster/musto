require "test_helper"

class TaxAgencyRegistrationTest < ActiveSupport::TestCase
  setup do
    organization = Organization.create!(name: "Tax Registration Org", external_id: "tax_registration_org")
    @employer = organization.employers.create!(name: "Tax Registration Employer", status: "active")
    @other_employer = organization.employers.create!(name: "Other Registration Employer", status: "active")
    @other_location = @other_employer.work_locations.create!(name: "Other HQ", country: "US", state: "CA")
  end

  test "requires work location to belong to employer" do
    registration = @employer.tax_agency_registrations.build(
      work_location: @other_location,
      agency_name: "California Employment Development Department",
      jurisdiction: "CA",
      registration_type: "unemployment_insurance",
      due_on: Date.current + 10.days
    )

    assert_not registration.valid?
    assert_includes registration.errors[:work_location], "must belong to employer"
  end

  test "requires submission timing when confirmation is present" do
    registration = @employer.tax_agency_registrations.build(
      agency_name: "Internal Revenue Service",
      jurisdiction: "Federal",
      registration_type: "federal_withholding",
      due_on: Date.current + 10.days,
      confirmation_number: "IRS-123"
    )

    assert_not registration.valid?
    assert_includes registration.errors[:confirmation_number], "requires submitted or confirmed timing"
  end
end
