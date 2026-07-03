module Benefits
  EligibilityBatchMemberDto = Data.define(
    :member_id,
    :member_type,
    :employee_id,
    :dependent_id,
    :name,
    :relationship,
    :plan_name,
    :plan_category,
    :coverage_level,
    :effective_on,
    :remote_member_id,
    :remote_enrollment_id,
    :status
  ) do
    def self.from_hash(payload)
      attributes = payload.to_h.stringify_keys

      new(
        member_id: attributes.fetch("member_id"),
        member_type: attributes.fetch("member_type"),
        employee_id: attributes.fetch("employee_id"),
        dependent_id: attributes.fetch("dependent_id", nil),
        name: attributes.fetch("name"),
        relationship: attributes.fetch("relationship"),
        plan_name: attributes.fetch("plan_name"),
        plan_category: attributes.fetch("plan_category"),
        coverage_level: attributes.fetch("coverage_level"),
        effective_on: Date.iso8601(attributes.fetch("effective_on")),
        remote_member_id: attributes.fetch("remote_member_id"),
        remote_enrollment_id: attributes.fetch("remote_enrollment_id"),
        status: attributes.fetch("status")
      )
    end
  end
end
