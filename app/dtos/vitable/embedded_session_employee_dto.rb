module Vitable
  EmbeddedSessionEmployeeDto = Data.define(
    :employee_id,
    :employee_name,
    :email,
    :department_name,
    :location_name,
    :remote_employee_id,
    :enrollment_ids,
    :plan_names,
    :pending_enrollment_count,
    :accepted_enrollment_count,
    :next_effective_on,
    :status,
    :readiness_reason
  ) do
    def self.from_hash(payload)
      attributes = payload.to_h.stringify_keys

      new(
        employee_id: attributes.fetch("employee_id"),
        employee_name: attributes.fetch("employee_name"),
        email: attributes.fetch("email"),
        department_name: attributes.fetch("department_name"),
        location_name: attributes.fetch("location_name"),
        remote_employee_id: attributes.fetch("remote_employee_id"),
        enrollment_ids: attributes.fetch("enrollment_ids", []),
        plan_names: attributes.fetch("plan_names", []),
        pending_enrollment_count: attributes.fetch("pending_enrollment_count", 0),
        accepted_enrollment_count: attributes.fetch("accepted_enrollment_count", 0),
        next_effective_on: attributes["next_effective_on"].present? ? Date.iso8601(attributes.fetch("next_effective_on")) : nil,
        status: attributes.fetch("status"),
        readiness_reason: attributes.fetch("readiness_reason")
      )
    end
  end
end
