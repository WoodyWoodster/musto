module Vitable
  CensusSyncHoldbackDto = Data.define(
    :employee_id,
    :employee_name,
    :email,
    :department_name,
    :location_name,
    :status,
    :reason_code,
    :reason
  ) do
    def self.from_hash(payload)
      attributes = payload.to_h.stringify_keys

      new(
        employee_id: attributes.fetch("employee_id"),
        employee_name: attributes.fetch("employee_name"),
        email: attributes.fetch("email"),
        department_name: attributes.fetch("department_name"),
        location_name: attributes.fetch("location_name"),
        status: attributes.fetch("status"),
        reason_code: attributes.fetch("reason_code"),
        reason: attributes.fetch("reason")
      )
    end
  end
end
