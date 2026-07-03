module YearEnd
  TaxFormDto = Data.define(
    :id,
    :employee_id,
    :contractor_id,
    :recipient_name,
    :recipient_email,
    :form_type,
    :tax_year,
    :tin_last4,
    :jurisdiction,
    :gross_wages_cents,
    :federal_withholding_cents,
    :state_withholding_cents,
    :benefit_reportable_cents,
    :contractor_payment_cents,
    :status,
    :delivery_method,
    :consent_status,
    :correction_status,
    :due_on,
    :filed_at,
    :delivered_at,
    :accepted_at,
    :deliverable,
    :delivered,
    :correction_needed
  ) do
    def self.from_record(form)
      new(
        id: form.id,
        employee_id: form.employee_id,
        contractor_id: form.contractor_id,
        recipient_name: form.recipient_name,
        recipient_email: form.recipient_email,
        form_type: form.form_type,
        tax_year: form.tax_year,
        tin_last4: form.tin_last4,
        jurisdiction: form.jurisdiction,
        gross_wages_cents: form.gross_wages_cents,
        federal_withholding_cents: form.federal_withholding_cents,
        state_withholding_cents: form.state_withholding_cents,
        benefit_reportable_cents: form.benefit_reportable_cents,
        contractor_payment_cents: form.contractor_payment_cents,
        status: form.status,
        delivery_method: form.delivery_method,
        consent_status: form.consent_status,
        correction_status: form.correction_status,
        due_on: form.due_on,
        filed_at: form.filed_at,
        delivered_at: form.delivered_at,
        accepted_at: form.accepted_at,
        deliverable: form.deliverable?,
        delivered: form.delivered?,
        correction_needed: form.correction_needed?
      )
    end

    def employee_form?
      form_type == "w2"
    end

    def contractor_form?
      form_type == "1099_nec"
    end
  end
end
