module Benefits
  EligibilityDependentDto = Data.define(
    :id,
    :employee_id,
    :employee_name,
    :full_name,
    :relationship,
    :date_of_birth,
    :enrollment_status,
    :eligibility_status,
    :vitable_id,
    :readiness_status
  ) do
    def self.from_record(record)
      new(
        id: record.id,
        employee_id: record.employee_id,
        employee_name: record.employee.full_name,
        full_name: record.full_name,
        relationship: record.relationship,
        date_of_birth: record.date_of_birth,
        enrollment_status: record.enrollment_status,
        eligibility_status: record.eligibility_status,
        vitable_id: record.vitable_id,
        readiness_status: record.eligible? ? "ready" : "needs_review"
      )
    end

    def eligible?
      readiness_status == "ready"
    end
  end
end
