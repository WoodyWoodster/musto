require "test_helper"

class ComplianceNoticeTest < ActiveSupport::TestCase
  setup do
    organization = Organization.create!(name: "Compliance Notice Org", external_id: "compliance_notice_org")
    @employer = organization.employers.create!(name: "Compliance Notice Employer", status: "active")
    @other_employer = organization.employers.create!(name: "Other Compliance Employer", status: "active")
    @other_employee = @other_employer.employees.create!(
      first_name: "Alex",
      last_name: "Stone",
      email: "alex.notice@example.com",
      compensation_cents: 80_000_00
    )
  end

  test "requires due date to be on or after received date" do
    notice = @employer.compliance_notices.build(
      source: "agency_mail",
      notice_type: "payroll_tax_deposit",
      title: "Deposit notice",
      agency_name: "Internal Revenue Service",
      jurisdiction: "Federal",
      received_on: Date.current,
      due_on: Date.current - 1.day
    )

    assert_not notice.valid?
    assert_includes notice.errors[:due_on], "must be on or after received on"
  end

  test "requires employee to belong to employer" do
    notice = @employer.compliance_notices.build(
      employee: @other_employee,
      source: "state_portal",
      notice_type: "wage_hour",
      title: "Wage notice",
      agency_name: "State Labor Department",
      jurisdiction: "CO",
      received_on: Date.current,
      due_on: Date.current + 10.days
    )

    assert_not notice.valid?
    assert_includes notice.errors[:employee], "must belong to employer"
  end
end
