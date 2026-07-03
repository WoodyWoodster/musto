module PayrollCalendar
  ChecklistLineDto = Data.define(:approval_step_id, :key, :title, :owner, :status, :severity, :due_at, :detail, :count, :amount_cents) do
    def self.from_hash(payload)
      attributes = payload.to_h.stringify_keys

      new(
        approval_step_id: attributes.fetch("approval_step_id"),
        key: attributes.fetch("key"),
        title: attributes.fetch("title"),
        owner: attributes.fetch("owner"),
        status: attributes.fetch("status"),
        severity: attributes.fetch("severity"),
        due_at: Time.iso8601(attributes.fetch("due_at")),
        detail: attributes.fetch("detail"),
        count: attributes.fetch("count", 0),
        amount_cents: attributes.fetch("amount_cents", 0)
      )
    end
  end
end
