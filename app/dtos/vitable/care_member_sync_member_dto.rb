module Vitable
  CareMemberSyncMemberDto = Data.define(
    :employee_id,
    :employee_name,
    :email,
    :phone,
    :date_of_birth,
    :department_name,
    :location_name,
    :plan_name,
    :plan_id,
    :reference_id,
    :remote_employee_id,
    :status,
    :readiness_status,
    :readiness_reason
  ) do
    def self.from_hash(payload)
      attributes = payload.to_h.stringify_keys

      new(
        employee_id: attributes.fetch("employee_id"),
        employee_name: attributes.fetch("employee_name"),
        email: attributes.fetch("email"),
        phone: attributes.fetch("phone"),
        date_of_birth: Date.iso8601(attributes.fetch("date_of_birth")),
        department_name: attributes.fetch("department_name"),
        location_name: attributes.fetch("location_name"),
        plan_name: attributes.fetch("plan_name"),
        plan_id: attributes.fetch("plan_id"),
        reference_id: attributes.fetch("reference_id"),
        remote_employee_id: attributes.fetch("remote_employee_id", nil),
        status: attributes.fetch("status"),
        readiness_status: attributes.fetch("readiness_status"),
        readiness_reason: attributes.fetch("readiness_reason")
      )
    end
  end
end
