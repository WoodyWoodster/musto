module Hiring
  HandoffBatchDto = Data.define(:batch_id, :generated_at, :requested_by, :status, :hire_count, :task_count, :holdback_count) do
    def self.from_hash(payload)
      attributes = payload.to_h.stringify_keys
      totals = attributes.fetch("totals", {}).to_h.stringify_keys

      new(
        batch_id: attributes.fetch("batch_id"),
        generated_at: Time.iso8601(attributes.fetch("generated_at")),
        requested_by: attributes.fetch("requested_by", "ops_console"),
        status: attributes.fetch("status"),
        hire_count: totals.fetch("hire_count", 0),
        task_count: totals.fetch("task_count", 0),
        holdback_count: totals.fetch("holdback_count", 0)
      )
    end
  end
end
