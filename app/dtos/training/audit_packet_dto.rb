module Training
  AuditPacketDto = Data.define(:batch_id, :status, :generated_at, :requested_by, :assignment_count, :employee_count, :holdback_count, :average_score) do
    def self.from_hash(payload)
      totals = payload.fetch("totals", {})

      new(
        batch_id: payload.fetch("batch_id", nil),
        status: payload.fetch("status", "empty"),
        generated_at: payload.fetch("generated_at", nil),
        requested_by: payload.fetch("requested_by", nil),
        assignment_count: totals.fetch("assignment_count", 0),
        employee_count: totals.fetch("employee_count", 0),
        holdback_count: totals.fetch("holdback_count", 0),
        average_score: totals.fetch("average_score", 0)
      )
    end
  end
end
