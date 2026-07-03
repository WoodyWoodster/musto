module Documents
  BatchDto = Data.define(:batch_id, :generated_at, :requested_by, :status, :request_count, :employee_count, :holdback_count) do
    def self.from_hash(payload)
      totals = payload.to_h.fetch("totals", {})

      new(
        batch_id: payload.fetch("batch_id"),
        generated_at: Time.zone.parse(payload.fetch("generated_at")),
        requested_by: payload.fetch("requested_by"),
        status: payload.fetch("status"),
        request_count: totals.fetch("request_count", 0),
        employee_count: totals.fetch("employee_count", 0),
        holdback_count: totals.fetch("holdback_count", 0)
      )
    end
  end
end
