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
    :readiness_reason,
    :session_status,
    :session_issued_at,
    :session_expires_at
  ) do
    def self.from_hash(payload)
      attributes = payload.to_h.stringify_keys
      issuance = attributes.fetch("latest_session", {}).to_h.stringify_keys

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
        readiness_reason: attributes.fetch("readiness_reason"),
        session_status: issuance.fetch("status", "not_issued"),
        session_issued_at: parse_time(issuance.fetch("issued_at", nil)),
        session_expires_at: parse_time(issuance.fetch("expires_at", nil))
      )
    end

    def session_active?(at: Time.current)
      session_status == "issued" && session_expires_at.present? && session_expires_at > at
    end

    def self.parse_time(value)
      return value if value.respond_to?(:iso8601)
      return if value.blank?

      Time.iso8601(value.to_s)
    rescue ArgumentError
      nil
    end
  end
end
