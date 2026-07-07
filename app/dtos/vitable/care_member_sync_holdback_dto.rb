module Vitable
  CareMemberSyncHoldbackDto = Data.define(
    :employee_id,
    :employee_name,
    :email,
    :department_name,
    :location_name,
    :plan_name,
    :plan_id,
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
        plan_name: attributes.fetch("plan_name", nil),
        plan_id: attributes.fetch("plan_id", nil),
        status: attributes.fetch("status"),
        reason_code: attributes.fetch("reason_code"),
        reason: attributes.fetch("reason")
      )
    end
  end
end
