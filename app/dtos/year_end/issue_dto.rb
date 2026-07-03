module YearEnd
  IssueDto = Data.define(
    :form_id,
    :recipient_name,
    :form_type,
    :tax_year,
    :severity,
    :status,
    :reason_code,
    :reason,
    :amount_cents
  ) do
    def self.from_hash(payload)
      attributes = payload.to_h.stringify_keys

      new(
        form_id: attributes.fetch("form_id"),
        recipient_name: attributes.fetch("recipient_name"),
        form_type: attributes.fetch("form_type"),
        tax_year: attributes.fetch("tax_year"),
        severity: attributes.fetch("severity"),
        status: attributes.fetch("status"),
        reason_code: attributes.fetch("reason_code"),
        reason: attributes.fetch("reason"),
        amount_cents: attributes.fetch("amount_cents", 0)
      )
    end
  end
end
