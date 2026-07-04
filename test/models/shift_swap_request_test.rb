require "test_helper"

class ShiftSwapRequestTest < ActiveSupport::TestCase
  setup do
    organization = Organization.create!(name: "Swap Org", external_id: "swap_org")
    @employer = organization.employers.create!(name: "Swap Employer", status: "active")
    @requester = @employer.employees.create!(first_name: "Casey", last_name: "Ng", email: "casey.swap@example.com")
    @target = @employer.employees.create!(first_name: "Ari", last_name: "Lopez", email: "ari.swap@example.com")
    @shift = @employer.work_shifts.create!(employee: @requester, role: "Support lead", starts_at: Time.current + 1.day, ends_at: Time.current + 1.day + 8.hours, hourly_rate_cents: 3_000, status: "published")
  end

  test "approves swap and reassigns shift" do
    swap = @shift.shift_swap_requests.create!(requester: @requester, target_employee: @target, reason: "Schedule conflict", submitted_at: 1.hour.ago)

    swap.approve!(reviewed_by: "manager")

    assert swap.approved?
    assert_equal @target, @shift.reload.employee
    assert_equal "manager", swap.reviewed_by
    assert_equal "manager", swap.metadata.fetch("approved_by")
  end
end
