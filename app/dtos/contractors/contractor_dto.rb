module Contractors
  ContractorDto = Data.define(
    :id,
    :employer_id,
    :full_name,
    :display_name,
    :business_name,
    :email,
    :contractor_type,
    :status,
    :tax_form_status,
    :payment_method_status,
    :start_on,
    :hourly_rate_cents,
    :pending_payment_cents,
    :approved_payment_cents,
    :payment_count,
    :readiness_status
  ) do
    def self.from_record(record)
      payments = record.contractor_payments

      new(
        id: record.id,
        employer_id: record.employer_id,
        full_name: record.full_name,
        display_name: record.display_name,
        business_name: record.business_name,
        email: record.email,
        contractor_type: record.contractor_type,
        status: record.status,
        tax_form_status: record.tax_form_status,
        payment_method_status: record.payment_method_status,
        start_on: record.start_on,
        hourly_rate_cents: record.hourly_rate_cents,
        pending_payment_cents: payments.select(&:draft?).sum(&:amount_cents),
        approved_payment_cents: payments.select(&:approved?).sum(&:amount_cents),
        payment_count: payments.count,
        readiness_status: record.ready_for_payment? ? "ready" : "needs_review"
      )
    end

    def ready_for_payment?
      readiness_status == "ready"
    end
  end
end
