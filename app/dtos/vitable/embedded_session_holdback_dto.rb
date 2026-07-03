module Vitable
  EmbeddedSessionHoldbackDto = Data.define(
    :employee_id,
    :employee_name,
    :email,
    :department_name,
    :location_name,
    :enrollment_ids,
    :plan_names,
    :pending_enrollment_count,
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
        enrollment_ids: attributes.fetch("enrollment_ids", []),
        plan_names: attributes.fetch("plan_names", []),
        pending_enrollment_count: attributes.fetch("pending_enrollment_count", 0),
        status: attributes.fetch("status"),
        reason_code: attributes.fetch("reason_code"),
        reason: attributes.fetch("reason")
      )
    end
  end
end
