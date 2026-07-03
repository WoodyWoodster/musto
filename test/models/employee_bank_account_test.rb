require "test_helper"

class EmployeeBankAccountTest < ActiveSupport::TestCase
  setup do
    organization = Organization.create!(name: "Direct Deposit Org", external_id: "direct_deposit_org")
    employer = organization.employers.create!(name: "Direct Deposit Employer", status: "active")
    @employee = employer.employees.create!(
      first_name: "Casey",
      last_name: "Ng",
      email: "casey.direct.deposit@example.com",
      compensation_cents: 95_000_00
    )
  end

  test "verifies employee account with reviewer metadata" do
    account = @employee.employee_bank_accounts.create!(
      nickname: "Primary checking",
      institution_name: "Ally",
      routing_number_last4: "1040",
      account_last4: "9088"
    )

    account.verify!(reviewed_by: "ops_console")

    assert_equal "verified", account.status
    assert account.ready_for_deposit?
    assert_equal "ops_console", account.metadata.fetch("verified_by")
    assert_not_nil account.verified_at
  end

  test "reports readiness for blocked accounts" do
    account = @employee.employee_bank_accounts.create!(
      nickname: "Blocked checking",
      institution_name: "Ally",
      routing_number_last4: "1040",
      account_last4: "9088",
      status: "blocked"
    )

    assert_not account.ready_for_deposit?
    assert_equal "blocked", account.readiness_status
  end
end
