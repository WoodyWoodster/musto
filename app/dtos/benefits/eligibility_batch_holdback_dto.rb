module Benefits
  EligibilityBatchHoldbackDto = Data.define(:source_type, :source_id, :employee_id, :employee_name, :label, :status, :reason) do
    def self.from_hash(payload)
      attributes = payload.to_h.stringify_keys

      new(
        source_type: attributes.fetch("source_type"),
        source_id: attributes.fetch("source_id"),
        employee_id: attributes.fetch("employee_id"),
        employee_name: attributes.fetch("employee_name"),
        label: attributes.fetch("label"),
        status: attributes.fetch("status"),
        reason: attributes.fetch("reason")
      )
    end
  end
end
