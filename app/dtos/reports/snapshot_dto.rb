module Reports
  SnapshotDto = Data.define(:snapshot_id, :generated_at, :status, :requested_by, :metric_count, :export_count) do
    def self.from_hash(payload)
      new(
        snapshot_id: payload.fetch("snapshot_id"),
        generated_at: Time.iso8601(payload.fetch("generated_at")),
        status: payload.fetch("status"),
        requested_by: payload.fetch("requested_by", "ops_console"),
        metric_count: payload.fetch("metrics", {}).count,
        export_count: payload.fetch("exports", []).count
      )
    end
  end
end
