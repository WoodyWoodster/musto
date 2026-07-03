module TimeOff
  AccrualPacketLineDto = Data.define(:line_type, :employee_id, :employee_name, :policy_name, :hours, :payroll_action, :status) do
    def self.from_hash(payload)
      attributes = payload.to_h.stringify_keys

      new(
        line_type: attributes.fetch("line_type"),
        employee_id: attributes.fetch("employee_id"),
        employee_name: attributes.fetch("employee_name"),
        policy_name: attributes.fetch("policy_name"),
        hours: attributes.fetch("hours", 0),
        payroll_action: attributes.fetch("payroll_action"),
        status: attributes.fetch("status")
      )
    end
  end
end
