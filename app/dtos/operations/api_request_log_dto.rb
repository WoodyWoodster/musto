module Operations
  ApiRequestLogDto = Data.define(:id, :operation, :method, :path, :status_code, :duration_ms, :error_class) do
    def self.from_record(record)
      new(
        id: record.id,
        operation: record.operation,
        method: record.method,
        path: record.path,
        status_code: record.status_code,
        duration_ms: record.duration_ms,
        error_class: record.error_class
      )
    end
  end
end
