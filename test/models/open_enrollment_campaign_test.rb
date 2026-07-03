require "test_helper"

class OpenEnrollmentCampaignTest < ActiveSupport::TestCase
  setup do
    organization = Organization.create!(name: "Campaign Org", external_id: "campaign_org")
    @employer = organization.employers.create!(name: "Campaign Employer", status: "active")
  end

  test "requires campaign window and plan year" do
    campaign = @employer.open_enrollment_campaigns.build

    assert_not campaign.valid?
    assert_includes campaign.errors[:name], "can't be blank"
    assert_includes campaign.errors[:plan_year], "can't be blank"
  end

  test "launch marks campaign active with audit metadata" do
    campaign = @employer.open_enrollment_campaigns.create!(
      name: "2027 Open Enrollment",
      plan_year: 2027,
      starts_on: Date.current,
      ends_on: Date.current + 21.days
    )

    campaign.launch!(requested_by: "benefits_admin")

    assert campaign.active?
    assert campaign.launched?
    assert_equal "benefits_admin", campaign.metadata.fetch("launched_by")
  end
end
