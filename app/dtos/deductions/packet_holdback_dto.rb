module Deductions
  PacketHoldbackDto = Data.define(:deduction_id, :employee_name, :title, :deduction_type, :amount_cents, :status, :reason) do
    def self.from_hash(payload)
      new(
        deduction_id: payload.fetch("deduction_id", nil),
        employee_name: payload.fetch("employee_name", "Deduction order"),
        title: payload.fetch("title", "Deduction"),
        deduction_type: payload.fetch("deduction_type", "other"),
        amount_cents: payload.fetch("amount_cents", 0),
        status: payload.fetch("status", "needs_review"),
        reason: payload.fetch("reason", "Needs review")
      )
    end
  end
end
