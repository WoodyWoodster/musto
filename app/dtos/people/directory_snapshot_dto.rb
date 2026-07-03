module People
  DirectorySnapshotDto = Data.define(:snapshot_id, :generated_at, :requested_by, :status, :employee_count, :manager_count, :assigned_count, :unassigned_count, :issue_count) do
    def self.from_hash(payload)
      attributes = payload.to_h.stringify_keys
      totals = attributes.fetch("totals", {}).to_h.stringify_keys

      new(
        snapshot_id: attributes.fetch("snapshot_id"),
        generated_at: Time.iso8601(attributes.fetch("generated_at")),
        requested_by: attributes.fetch("requested_by", "ops_console"),
        status: attributes.fetch("status"),
        employee_count: totals.fetch("employee_count", 0),
        manager_count: totals.fetch("manager_count", 0),
        assigned_count: totals.fetch("assigned_count", 0),
        unassigned_count: totals.fetch("unassigned_count", 0),
        issue_count: totals.fetch("issue_count", 0)
      )
    end
  end
end
