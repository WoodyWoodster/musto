module Benefits
  BillingPacketHoldbackDto = Data.define(:invoice_line_id, :employee_id, :employee_name, :plan_name, :amount_cents, :reason, :status) do
    def self.from_hash(payload)
      new(
        invoice_line_id: payload.fetch("invoice_line_id"),
        employee_id: payload.fetch("employee_id"),
        employee_name: payload.fetch("employee_name"),
        plan_name: payload.fetch("plan_name"),
        amount_cents: payload.fetch("amount_cents"),
        reason: payload.fetch("reason"),
        status: payload.fetch("status")
      )
    end
  end
end
