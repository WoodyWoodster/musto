module EmployeeChanges
  SyncHoldbackDto = Data.define(:request_id, :employee_name, :request_type, :reason, :status) do
    def self.from_hash(payload)
      attributes = payload.to_h.stringify_keys

      new(
        request_id: attributes.fetch("request_id", nil),
        employee_name: attributes.fetch("employee_name"),
        request_type: attributes.fetch("request_type"),
        reason: attributes.fetch("reason"),
        status: attributes.fetch("status")
      )
    end
  end
end
