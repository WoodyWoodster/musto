require "test_helper"

class EmployeeDeductionTest < ActiveSupport::TestCase
  setup do
    organization = Organization.create!(name: "Deduction Org", external_id: "deduction_org")
    @employer = organization.employers.create!(name: "Deduction Employer", status: "active")
    @employee = @employer.employees.create!(first_name: "Casey", last_name: "Ng", email: "casey.deduction@example.com", compensation_cents: 120_000_00)
  end

  test "estimates percent deduction with per-paycheck cap" do
    deduction = @employer.employee_deductions.create!(
      employee: @employee,
      title: "Retirement deferral",
      deduction_type: "retirement",
      status: "active",
      calculation_method: "percent_gross",
      amount_cents: 0,
      percent_basis_points: 1_000,
      max_per_paycheck_cents: 400_00,
      starts_on: Date.current
    )

    assert_equal 400_00, deduction.estimated_amount_for(5_000_00)
  end

  test "activates pending deduction with audit metadata" do
    deduction = @employer.employee_deductions.create!(
      employee: @employee,
      title: "Child support",
      deduction_type: "child_support",
      status: "pending",
      amount_cents: 250_00,
      starts_on: Date.current
    )

    deduction.activate!(approved_by: "payroll_admin")

    assert deduction.active?
    assert_equal "payroll_admin", deduction.metadata.fetch("approved_by")
    assert_not_nil deduction.approved_at
  end

  test "requires percent value for percent calculations" do
    deduction = @employer.employee_deductions.build(
      employee: @employee,
      title: "Invalid percent",
      deduction_type: "retirement",
      calculation_method: "percent_gross",
      amount_cents: 0,
      starts_on: Date.current
    )

    assert_not deduction.valid?
    assert_includes deduction.errors[:base], "Deduction calculation must include an amount or percent"
  end
end
