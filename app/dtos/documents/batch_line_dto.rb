module Documents
  BatchLineDto = Data.define(:employee_id, :employee_name, :document_id, :title, :document_type, :status, :requested_at) do
    def self.from_hash(payload)
      new(
        employee_id: payload.fetch("employee_id"),
        employee_name: payload.fetch("employee_name"),
        document_id: payload.fetch("document_id"),
        title: payload.fetch("title"),
        document_type: payload.fetch("document_type"),
        status: payload.fetch("status"),
        requested_at: Time.zone.parse(payload.fetch("requested_at"))
      )
    end
  end
end
