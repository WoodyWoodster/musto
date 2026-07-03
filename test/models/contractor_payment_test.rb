require "test_helper"

class ContractorPaymentTest < ActiveSupport::TestCase
  setup do
    organization = Organization.create!(name: "Contractor Org", external_id: "contractor_org")
    employer = organization.employers.create!(name: "Contractor Employer", status: "active")
    @contractor = employer.contractors.create!(
      first_name: "Devon",
      last_name: "Stone",
      email: "devon.contractor@example.com",
      status: "active",
      tax_form_status: "complete",
      payment_method_status: "verified",
      hourly_rate_cents: 8_500
    )
  end

  test "approves payment with reviewer metadata" do
    payment = @contractor.contractor_payments.create!(
      work_period_start_on: Date.current.beginning_of_month,
      work_period_end_on: Date.current.end_of_month,
      pay_date: Date.current.end_of_month,
      description: "Implementation support",
      amount_cents: 2_500_00
    )

    payment.approve!(reviewed_by: "ops_console")

    assert_equal "approved", payment.status
    assert_equal "ops_console", payment.metadata.fetch("reviewed_by")
    assert_not_nil payment.approved_at
  end

  test "requires period end on or after period start" do
    payment = @contractor.contractor_payments.build(
      work_period_start_on: Date.current.end_of_month,
      work_period_end_on: Date.current.beginning_of_month,
      pay_date: Date.current.end_of_month,
      description: "Invalid period",
      amount_cents: 2_500_00
    )

    assert_not payment.valid?
    assert_includes payment.errors[:work_period_end_on], "must be on or after the period start"
  end
end
