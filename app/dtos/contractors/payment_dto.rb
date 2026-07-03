module Contractors
  PaymentDto = Data.define(
    :id,
    :contractor_id,
    :contractor_name,
    :business_name,
    :description,
    :work_period_start_on,
    :work_period_end_on,
    :pay_date,
    :amount_cents,
    :status,
    :payment_method,
    :approved_at,
    :contractor_status,
    :tax_form_status,
    :payment_method_status
  ) do
    def self.from_record(record)
      contractor = record.contractor

      new(
        id: record.id,
        contractor_id: record.contractor_id,
        contractor_name: contractor.full_name,
        business_name: contractor.business_name,
        description: record.description,
        work_period_start_on: record.work_period_start_on,
        work_period_end_on: record.work_period_end_on,
        pay_date: record.pay_date,
        amount_cents: record.amount_cents,
        status: record.status,
        payment_method: record.payment_method,
        approved_at: record.approved_at,
        contractor_status: contractor.status,
        tax_form_status: contractor.tax_form_status,
        payment_method_status: contractor.payment_method_status
      )
    end

    def draft?
      status == "draft"
    end

    def approved?
      status == "approved"
    end

    def blocked?
      status == "blocked"
    end

    def ready_for_approval?
      draft? && contractor_status == "active" && tax_form_status == "complete" && payment_method_status == "verified"
    end
  end
end
