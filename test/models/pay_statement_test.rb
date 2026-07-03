require "test_helper"

class PayStatementTest < ActiveSupport::TestCase
  setup do
    organization = Organization.create!(name: "Statement Org", external_id: "statement_org")
    employer = organization.employers.create!(name: "Statement Employer", status: "active")
    @employee = employer.employees.create!(
      first_name: "Casey",
      last_name: "Ng",
      email: "casey.statement@example.com",
      compensation_cents: 95_000_00
    )
    @payroll_run = employer.payroll_runs.create!(period_start_on: Date.current.beginning_of_month, period_end_on: Date.current.end_of_month, pay_date: Date.current.end_of_month, gross_pay_cents: 9_500_00)
  end

  test "delivers a generated statement with audit metadata" do
    statement = statement_record

    statement.deliver!(delivered_by: "ops_console")

    assert_equal "delivered", statement.status
    assert_equal "ops_console", statement.metadata.fetch("delivered_by")
    assert_not_nil statement.delivered_at
  end

  test "requires period end on or after period start" do
    statement = statement_record(period_start_on: Date.current.end_of_month, period_end_on: Date.current.beginning_of_month)

    assert_not statement.valid?
    assert_includes statement.errors[:period_end_on], "must be on or after the period start date"
  end

  private

  def statement_record(attributes = {})
    defaults = {
      payroll_run: @payroll_run,
      employee: @employee,
      statement_number: "PS-#{@payroll_run.id}-#{@employee.id}",
      period_start_on: @payroll_run.period_start_on,
      period_end_on: @payroll_run.period_end_on,
      pay_date: @payroll_run.pay_date,
      gross_pay_cents: 4_000_00,
      deduction_cents: 100_00,
      tax_cents: 720_00,
      net_pay_cents: 3_180_00
    }

    PayStatement.new(defaults.merge(attributes))
  end
end
