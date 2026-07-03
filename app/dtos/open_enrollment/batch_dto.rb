module OpenEnrollment
  BatchDto = Data.define(:batch_id, :batch_type, :generated_at, :requested_by, :status, :sent_count, :reminder_count, :holdback_count) do
    def self.from_hash(payload)
      totals = payload.to_h.fetch("totals", {})

      new(
        batch_id: payload.fetch("batch_id"),
        batch_type: payload.fetch("batch_type"),
        generated_at: Time.zone.parse(payload.fetch("generated_at")),
        requested_by: payload.fetch("requested_by"),
        status: payload.fetch("status"),
        sent_count: totals.fetch("sent_count", 0),
        reminder_count: totals.fetch("reminder_count", 0),
        holdback_count: totals.fetch("holdback_count", 0)
      )
    end
  end
end
