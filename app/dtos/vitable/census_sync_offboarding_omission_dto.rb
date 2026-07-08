module Vitable
  CensusSyncOffboardingOmissionDto = Data.define(
    :employee_id,
    :employee_name,
    :event_id,
    :reference_id,
    :remote_employee_id,
    :coverage_end_on,
    :reason_code,
    :reason,
    :status,
    :readiness_status,
    :readiness_reason,
    :submitted_at,
    :accepted_at
  ) do
    def self.from_hash(payload)
      attributes = payload.to_h.stringify_keys

      new(
        employee_id: attributes.fetch("employee_id"),
        employee_name: attributes.fetch("employee_name"),
        event_id: attributes.fetch("event_id", nil),
        reference_id: attributes.fetch("reference_id"),
        remote_employee_id: attributes.fetch("remote_employee_id", nil),
        coverage_end_on: attributes["coverage_end_on"].present? ? Date.iso8601(attributes.fetch("coverage_end_on")) : nil,
        reason_code: attributes.fetch("reason_code"),
        reason: attributes.fetch("reason"),
        status: attributes.fetch("status", "ready"),
        readiness_status: attributes.fetch("readiness_status", "ready"),
        readiness_reason: attributes.fetch("readiness_reason", nil),
        submitted_at: attributes["submitted_at"].present? ? Time.iso8601(attributes.fetch("submitted_at")) : nil,
        accepted_at: attributes["accepted_at"].present? ? Time.iso8601(attributes.fetch("accepted_at")) : nil
      )
    end
  end
end
