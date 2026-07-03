module Performance
  CalibrationBatchDto = Data.define(:batch_id, :generated_at, :requested_by, :status, :review_count, :employee_count, :holdback_count, :average_rating) do
    def self.from_hash(payload)
      attributes = payload.to_h.stringify_keys
      totals = attributes.fetch("totals", {}).to_h.stringify_keys

      new(
        batch_id: attributes.fetch("batch_id"),
        generated_at: Time.iso8601(attributes.fetch("generated_at")),
        requested_by: attributes.fetch("requested_by", "ops_console"),
        status: attributes.fetch("status"),
        review_count: totals.fetch("review_count", 0),
        employee_count: totals.fetch("employee_count", 0),
        holdback_count: totals.fetch("holdback_count", 0),
        average_rating: totals.fetch("average_rating", 0)
      )
    end
  end
end
