require "test_helper"

class BenefitInvoiceTest < ActiveSupport::TestCase
  setup do
    organization = Organization.create!(name: "Billing Org", external_id: "billing_org")
    @employer = organization.employers.create!(name: "Billing Employer", status: "active")
  end

  test "requires invoice identity and totals" do
    invoice = @employer.benefit_invoices.build

    assert_not invoice.valid?
    assert_includes invoice.errors[:invoice_number], "can't be blank"
    assert_includes invoice.errors[:carrier], "can't be blank"
  end

  test "approves invoice with audit metadata" do
    invoice = @employer.benefit_invoices.create!(
      invoice_number: "VIT-TEST-1",
      carrier: "Vitable",
      period_start_on: Date.current.beginning_of_month,
      period_end_on: Date.current.end_of_month,
      due_on: Date.current.end_of_month + 10.days
    )

    invoice.approve!(reviewed_by: "finance_admin")

    assert_equal "approved", invoice.status
    assert_equal "finance_admin", invoice.metadata.fetch("approved_by")
    assert_not_nil invoice.approved_at
  end
end
