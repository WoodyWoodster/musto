require "test_helper"

class EmployeeChangeRequestTest < ActiveSupport::TestCase
  setup do
    organization = Organization.create!(name: "Change Org", external_id: "change_org")
    employer = organization.employers.create!(name: "Change Employer", status: "active")
    @employee = employer.employees.create!(
      first_name: "Casey",
      last_name: "Ng",
      email: "casey.change@example.com",
      onboarding_status: "complete"
    )
  end

  test "exposes payload and impact helpers" do
    request = @employee.employee_change_requests.create!(
      request_type: "tax_withholding",
      title: "Update W-4",
      status: "submitted",
      effective_on: Date.current,
      submitted_at: Time.current,
      metadata: {
        payload: { filing_status: "single" },
        impact: { payroll: "tax_withholding_update", benefits: "none", compliance: "w4_document" }
      }
    )

    assert request.reviewable?
    assert_equal "single", request.payload.fetch("filing_status")
    assert_equal "tax_withholding_update", request.payroll_impact
    assert_equal "w4_document", request.compliance_impact
  end

  test "requires supported type and status" do
    request = @employee.employee_change_requests.build(
      request_type: "unsupported",
      title: "Invalid request",
      status: "waiting",
      effective_on: Date.current,
      submitted_at: Time.current
    )

    assert_not request.valid?
    assert_includes request.errors[:request_type], "is not included in the list"
    assert_includes request.errors[:status], "is not included in the list"
  end

  test "queues applied request for sync" do
    request = @employee.employee_change_requests.create!(
      request_type: "profile_update",
      title: "Update preferred name",
      status: "applied",
      effective_on: Date.current,
      submitted_at: Time.current
    )

    request.queue_for_sync!(batch_id: "employee_changes_1_123")

    assert request.sync_queued?
    assert_equal "employee_changes_1_123", request.metadata.fetch("sync_batch_id")
  end
end
