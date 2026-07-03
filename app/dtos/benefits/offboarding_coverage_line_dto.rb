module Benefits
  OffboardingCoverageLineDto = Data.define(
    :event_id,
    :employee_id,
    :employee_name,
    :member_type,
    :member_id,
    :member_name,
    :relationship,
    :plan_name,
    :plan_category,
    :remote_member_id,
    :remote_enrollment_id,
    :coverage_end_on,
    :status,
    :reason
  ) do
    def self.from_hash(payload)
      attributes = payload.to_h.stringify_keys

      new(
        event_id: attributes.fetch("event_id"),
        employee_id: attributes.fetch("employee_id"),
        employee_name: attributes.fetch("employee_name"),
        member_type: attributes.fetch("member_type"),
        member_id: attributes.fetch("member_id"),
        member_name: attributes.fetch("member_name"),
        relationship: attributes.fetch("relationship"),
        plan_name: attributes.fetch("plan_name"),
        plan_category: attributes.fetch("plan_category"),
        remote_member_id: attributes.fetch("remote_member_id", nil),
        remote_enrollment_id: attributes.fetch("remote_enrollment_id", nil),
        coverage_end_on: Date.iso8601(attributes.fetch("coverage_end_on")),
        status: attributes.fetch("status"),
        reason: attributes.fetch("reason")
      )
    end

    def ready?
      status == "ready"
    end
  end
end
