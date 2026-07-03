module Operations
  DocumentExceptionDto = Data.define(:id, :employee_name, :title, :document_type, :expires_on, :status) do
    def self.from_record(record)
      new(
        id: record.id,
        employee_name: record.employee.full_name,
        title: record.title,
        document_type: record.document_type,
        expires_on: record.expires_on,
        status: record.status
      )
    end
  end
end
