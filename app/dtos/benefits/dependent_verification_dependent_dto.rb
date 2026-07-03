module Benefits
  DependentVerificationDependentDto = Data.define(
    :dependent_id,
    :dependent_name,
    :employee_id,
    :employee_name,
    :relationship,
    :date_of_birth,
    :enrollment_status,
    :eligibility_status,
    :verification_id,
    :verification_status,
    :verification_type,
    :due_on,
    :document_status,
    :remote_dependent_id,
    :readiness_status,
    :readiness_reason
  ) do
    def self.from_record(record, verification:)
      document = verification&.employee_document
      readiness = readiness_for(record, verification)

      new(
        dependent_id: record.id,
        dependent_name: record.full_name,
        employee_id: record.employee_id,
        employee_name: record.employee.full_name,
        relationship: record.relationship,
        date_of_birth: record.date_of_birth,
        enrollment_status: record.enrollment_status,
        eligibility_status: record.eligibility_status,
        verification_id: verification&.id,
        verification_status: verification&.status || "missing",
        verification_type: verification&.verification_type || default_verification_type(record),
        due_on: verification&.due_on,
        document_status: document&.status || "missing",
        remote_dependent_id: record.vitable_id,
        readiness_status: readiness.fetch(:status),
        readiness_reason: readiness.fetch(:reason)
      )
    end

    def ready?
      readiness_status == "ready"
    end

    private_class_method def self.default_verification_type(record)
      record.relationship.in?([ "child", "step_child" ]) ? "birth_certificate" : "relationship_proof"
    end

    private_class_method def self.readiness_for(record, verification)
      return { status: "ready", reason: "Dependent is verified for eligibility sync." } if record.eligible? && verification&.approved?
      return { status: "blocked", reason: "Dependent verification was rejected." } if verification&.rejected?
      return { status: "needs_review", reason: "Dependent verification document is missing." } if verification.blank? || verification.employee_document.blank?
      return { status: "needs_review", reason: "Verification document is not complete." } unless verification.employee_document.complete?

      { status: "needs_review", reason: "Verification is waiting on benefits review." }
    end
  end
end
