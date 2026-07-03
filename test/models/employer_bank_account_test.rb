require "test_helper"

class EmployerBankAccountTest < ActiveSupport::TestCase
  setup do
    organization = Organization.create!(name: "Funding Org", external_id: "funding_org")
    @employer = organization.employers.create!(name: "Funding Employer", status: "active")
  end

  test "verifies employer funding account with reviewer metadata" do
    account = @employer.employer_bank_accounts.create!(
      name: "Payroll checking",
      institution_name: "Mercury Bank",
      routing_number_last4: "1101",
      account_last4: "4821"
    )

    account.verify!(reviewed_by: "ops_console")

    assert_equal "verified", account.status
    assert account.ready_for_funding?
    assert_equal "ops_console", account.metadata.fetch("verified_by")
    assert_not_nil account.verified_at
  end

  test "requires masked bank digits" do
    account = @employer.employer_bank_accounts.build(
      name: "Payroll checking",
      institution_name: "Mercury Bank",
      routing_number_last4: "11",
      account_last4: "4821"
    )

    assert_not account.valid?
    assert_includes account.errors[:routing_number_last4], "is the wrong length (should be 4 characters)"
  end
end
