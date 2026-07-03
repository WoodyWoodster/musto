module Documents
  BatchHoldbackDto = Data.define(:employee_id, :employee_name, :title, :reason, :status) do
    def self.from_hash(payload)
      new(
        employee_id: payload.fetch("employee_id"),
        employee_name: payload.fetch("employee_name"),
        title: payload.fetch("title"),
        reason: payload.fetch("reason"),
        status: payload.fetch("status")
      )
    end
  end
end
