module Operations
  SyncRunDto = Data.define(:id, :operation, :resource_type, :status, :started_at, :error_message) do
    def self.from_record(record)
      new(
        id: record.id,
        operation: record.operation,
        resource_type: record.resource_type,
        status: record.status,
        started_at: record.started_at,
        error_message: record.error_message
      )
    end
  end
end
