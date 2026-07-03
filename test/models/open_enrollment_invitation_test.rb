require "test_helper"

class OpenEnrollmentInvitationTest < ActiveSupport::TestCase
  setup do
    organization = Organization.create!(name: "Invite Org", external_id: "invite_org")
    employer = organization.employers.create!(name: "Invite Employer", status: "active")
    @employee = employer.employees.create!(first_name: "Jamie", last_name: "Stone", email: "jamie@example.com")
    @campaign = employer.open_enrollment_campaigns.create!(name: "2027 Open Enrollment", plan_year: 2027, starts_on: Date.current, ends_on: Date.current + 21.days)
  end

  test "tracks remindable and overdue state" do
    invitation = @campaign.open_enrollment_invitations.create!(employee: @employee, status: "sent", due_on: Date.current - 1.day, sent_at: 2.days.ago)

    assert invitation.sent?
    assert invitation.remindable?
    assert invitation.overdue?
  end

  test "completed invitations are not remindable" do
    invitation = @campaign.open_enrollment_invitations.create!(employee: @employee, status: "completed", due_on: Date.current + 1.day, completed_at: Time.current)

    assert invitation.completed?
    assert_not invitation.remindable?
  end
end
