module Benefits
  DependentVerificationPacketLineDto = Data.define(:dependent_id, :dependent_name, :employee_id, :employee_name, :relationship, :remote_dependent_id, :verification_type, :status) do
    def self.from_hash(payload)
      attributes = payload.to_h.stringify_keys

      new(
        dependent_id: attributes.fetch("dependent_id"),
        dependent_name: attributes.fetch("dependent_name"),
        employee_id: attributes.fetch("employee_id"),
        employee_name: attributes.fetch("employee_name"),
        relationship: attributes.fetch("relationship"),
        remote_dependent_id: attributes.fetch("remote_dependent_id"),
        verification_type: attributes.fetch("verification_type"),
        status: attributes.fetch("status")
      )
    end
  end
end
