require "test_helper"

class BenefitInvoiceLineTest < ActiveSupport::TestCase
  setup do
    organization = Organization.create!(name: "Line Org", external_id: "line_org")
    employer = organization.employers.create!(name: "Line Employer", status: "active")
    employee = employer.employees.create!(first_name: "Alex", last_name: "Morgan", email: "alex@example.com")
    plan = employer.benefit_plans.create!(name: "Primary Care", category: "direct_primary_care", monthly_premium_cents: 10_000)
    enrollment = employee.enrollments.create!(benefit_plan: plan, status: "accepted")
    invoice = employer.benefit_invoices.create!(invoice_number: "VIT-LINE-1", carrier: "Vitable", period_start_on: Date.current.beginning_of_month, period_end_on: Date.current.end_of_month, due_on: Date.current.end_of_month + 10.days)
    @line = invoice.benefit_invoice_lines.create!(
      employee:,
      benefit_plan: plan,
      enrollment:,
      coverage_level: "employee",
      amount_cents: 11_000,
      expected_premium_cents: 10_000,
      expected_payroll_deduction_cents: 4_000,
      employee_contribution_cents: 4_000,
      employer_contribution_cents: 7_000,
      variance_cents: 1_000,
      status: "variance"
    )
  end

  test "flags variance lines as blocked" do
    assert @line.blocked?
    assert_not @line.matched?
  end
end
