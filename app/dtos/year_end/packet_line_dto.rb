module YearEnd
  PacketLineDto = Data.define(
    :form_id,
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
    :delivered_at,
    :accepted_at
  ) do
    def self.from_hash(payload)
      attributes = payload.to_h.stringify_keys

      new(
        form_id: attributes.fetch("form_id"),
        employee_id: attributes.fetch("employee_id", nil),
        contractor_id: attributes.fetch("contractor_id", nil),
        recipient_name: attributes.fetch("recipient_name"),
        recipient_email: attributes.fetch("recipient_email"),
        form_type: attributes.fetch("form_type"),
        tax_year: attributes.fetch("tax_year"),
        tin_last4: attributes.fetch("tin_last4", nil),
        jurisdiction: attributes.fetch("jurisdiction"),
        gross_wages_cents: attributes.fetch("gross_wages_cents", 0),
        federal_withholding_cents: attributes.fetch("federal_withholding_cents", 0),
        state_withholding_cents: attributes.fetch("state_withholding_cents", 0),
        benefit_reportable_cents: attributes.fetch("benefit_reportable_cents", 0),
        contractor_payment_cents: attributes.fetch("contractor_payment_cents", 0),
        status: attributes.fetch("status"),
        delivery_method: attributes.fetch("delivery_method"),
        consent_status: attributes.fetch("consent_status"),
        correction_status: attributes.fetch("correction_status"),
        due_on: Date.iso8601(attributes.fetch("due_on")),
        delivered_at: parse_time(attributes.fetch("delivered_at", nil)),
        accepted_at: parse_time(attributes.fetch("accepted_at", nil))
      )
    end

    def self.parse_time(value)
      value.present? ? Time.iso8601(value) : nil
    end
  end
end
