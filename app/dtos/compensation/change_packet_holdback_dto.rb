module Compensation
  ChangePacketHoldbackDto = Data.define(:change_id, :employee_id, :employee_name, :change_type, :status, :reason) do
    def self.from_hash(payload)
      attributes = payload.to_h.stringify_keys

      new(
        change_id: attributes.fetch("change_id", nil),
        employee_id: attributes.fetch("employee_id", nil),
        employee_name: attributes.fetch("employee_name"),
        change_type: attributes.fetch("change_type"),
        status: attributes.fetch("status"),
        reason: attributes.fetch("reason")
      )
    end
  end
end
