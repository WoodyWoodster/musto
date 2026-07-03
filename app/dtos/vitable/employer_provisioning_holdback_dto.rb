module Vitable
  EmployerProvisioningHoldbackDto = Data.define(:field, :status, :reason_code, :reason) do
    def self.from_hash(payload)
      attributes = payload.to_h.stringify_keys

      new(
        field: attributes.fetch("field"),
        status: attributes.fetch("status"),
        reason_code: attributes.fetch("reason_code"),
        reason: attributes.fetch("reason")
      )
    end
  end
end
