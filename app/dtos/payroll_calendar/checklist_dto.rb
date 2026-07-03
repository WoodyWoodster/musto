module PayrollCalendar
  ChecklistDto = Data.define(:batch_id, :generated_at, :requested_by, :status, :step_count, :blocked_count, :completed_count) do
    def self.from_hash(payload)
      attributes = payload.to_h.stringify_keys
      totals = attributes.fetch("totals", {}).to_h.stringify_keys

      new(
        batch_id: attributes.fetch("batch_id"),
        generated_at: Time.iso8601(attributes.fetch("generated_at")),
        requested_by: attributes.fetch("requested_by", "ops_console"),
        status: attributes.fetch("status"),
        step_count: totals.fetch("step_count", 0),
        blocked_count: totals.fetch("blocked_count", 0),
        completed_count: totals.fetch("completed_count", 0)
      )
    end
  end
end
