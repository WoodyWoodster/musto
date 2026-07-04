require "test_helper"

class EmployeeExpenseTest < ActiveSupport::TestCase
  setup do
    organization = Organization.create!(name: "Expense Org", external_id: "expense_org")
    employer = organization.employers.create!(name: "Expense Employer", status: "active")
    @employee = employer.employees.create!(
      first_name: "Casey",
      last_name: "Ng",
      email: "casey.expense@example.com",
      compensation_cents: 95_000_00
    )
  end

  test "approves a policy-ready employee expense with reviewer metadata" do
    expense = @employee.employee_expenses.create!(
      incurred_on: Date.current - 1.day,
      merchant: "Amtrak",
      category: "travel",
      description: "Benefits kickoff travel",
      amount_cents: 184_00,
      receipt_status: "uploaded"
    )

    expense.approve!(reviewed_by: "ops_console")

    assert_equal "approved", expense.status
    assert_equal "ops_console", expense.metadata.fetch("reviewed_by")
    assert_not_nil expense.approved_at
  end

  test "blocks policy readiness without a receipt" do
    expense = @employee.employee_expenses.create!(
      incurred_on: Date.current,
      merchant: "Client services",
      category: "meals",
      description: "Team lunch",
      amount_cents: 145_00
    )

    assert_not expense.policy_ready?
    assert_equal "Receipt is missing", expense.approval_block_reason
  end
end
