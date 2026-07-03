module Operations
  ComplianceCaseDto = Data.define(:id, :kind, :severity, :status, :employee_name, :due_on, :description) do
    def self.from_record(record)
      new(
        id: record.id,
        kind: record.kind,
        severity: record.severity,
        status: record.status,
        employee_name: record.employee&.full_name,
        due_on: record.due_on,
        description: record.description
      )
    end

    def resolved?
      status == "resolved"
    end
  end
end
