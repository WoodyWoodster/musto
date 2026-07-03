require "test_helper"

class YearEndTaxFormTest < ActiveSupport::TestCase
  setup do
    organization = Organization.create!(name: "Year End Org", external_id: "year_end_org")
    @employer = organization.employers.create!(name: "Year End Employer", status: "active")
    @employee = @employer.employees.create!(
      first_name: "Riley",
      last_name: "Tax",
      email: "riley.tax@example.com",
      compensation_cents: 90_000_00
    )
    @contractor = @employer.contractors.create!(
      first_name: "Morgan",
      last_name: "Vendor",
      email: "morgan.vendor@example.com",
      contractor_type: "individual",
      status: "active",
      tax_form_status: "complete",
      payment_method_status: "verified",
      hourly_rate_cents: 125_00
    )
  end

  test "requires exactly one recipient" do
    blank_form = build_tax_form(employee: nil, contractor: nil)
    dual_recipient_form = build_tax_form(employee: @employee, contractor: @contractor)

    assert_not blank_form.valid?
    assert_includes blank_form.errors[:base], "must have exactly one employee or contractor recipient"
    assert_not dual_recipient_form.valid?
    assert_includes dual_recipient_form.errors[:base], "must have exactly one employee or contractor recipient"
  end

  test "requires form type to match recipient type" do
    employee_form = build_tax_form(employee: @employee, form_type: "1099_nec")
    contractor_form = build_tax_form(contractor: @contractor, form_type: "w2", delivery_method: "contractor_portal")

    assert_not employee_form.valid?
    assert_includes employee_form.errors[:form_type], "must be w2 for employees"
    assert_not contractor_form.valid?
    assert_includes contractor_form.errors[:form_type], "must be 1099_nec for contractors"
  end

  test "requires recipient to belong to employer" do
    other_employer = Organization.create!(name: "Other Year End Org", external_id: "other_year_end_org").employers.create!(name: "Other Year End Employer", status: "active")
    form = other_employer.year_end_tax_forms.build(
      employee: @employee,
      tax_year: Date.current.year,
      form_type: "w2",
      recipient_name: @employee.full_name,
      recipient_email: @employee.email,
      jurisdiction: "Federal",
      due_on: Date.new(Date.current.year + 1, 1, 31)
    )

    assert_not form.valid?
    assert_includes form.errors[:employee], "must belong to employer"
  end

  private

  def build_tax_form(employee: nil, contractor: nil, form_type: "w2", delivery_method: "employee_portal")
    @employer.year_end_tax_forms.build(
      employee:,
      contractor:,
      tax_year: Date.current.year,
      form_type:,
      recipient_name: employee&.full_name || contractor&.display_name || "Missing Recipient",
      recipient_email: employee&.email || contractor&.email || "missing@example.com",
      jurisdiction: "Federal",
      gross_wages_cents: employee.present? ? 10_000_00 : 0,
      contractor_payment_cents: contractor.present? ? 1_000_00 : 0,
      delivery_method:,
      due_on: Date.new(Date.current.year + 1, 1, 31)
    )
  end
end
