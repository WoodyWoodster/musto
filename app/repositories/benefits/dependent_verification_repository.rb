module Benefits
  class DependentVerificationRepository < ApplicationRepository
    PACKET_KEY = "dependent_verification_packet"

    def initialize(employer:)
      @employer = employer
    end

    def dependents
      return Dependent.none unless @employer

      Dependent
        .joins(:employee)
        .where(employees: { employer_id: @employer.id })
        .includes(:dependent_verifications, employee: [ :employee_documents, :department, :work_location ])
        .order(:last_name, :first_name)
    end

    def verifications
      return DependentVerification.none unless @employer

      DependentVerification
        .joins(dependent: :employee)
        .where(employees: { employer_id: @employer.id })
        .includes(:employee_document, dependent: [ employee: [ :department, :work_location ] ])
        .recent_first
    end

    def latest_packet
      @employer&.settings.to_h.fetch(PACKET_KEY, nil)
    end

    def find_verification(id)
      verifications.find(id)
    end

    def request_missing_verifications(requested_by:)
      dependents.filter_map do |dependent|
        next if approved_verification?(dependent)

        verification = dependent.dependent_verifications.find_or_initialize_by(verification_type: verification_type_for(dependent))
        verification.assign_attributes(
          employee_document: verification.employee_document || latest_benefits_document(dependent),
          status: verification.status == "approved" ? "approved" : verification_status_for(dependent),
          requested_on: verification.requested_on || Date.current,
          due_on: verification.due_on || 14.days.from_now.to_date,
          metadata: verification.metadata.to_h.merge(
            "requested_by" => requested_by,
            "requested_from" => "dependent_verification_center",
            "requested_at" => Time.current.iso8601
          )
        )
        verification.save!
        verification
      end
    end

    def approve_verification(verification, reviewed_by:)
      DependentVerification.transaction do
        verification.update!(
          status: "approved",
          issue_code: nil,
          reviewed_at: Time.current,
          reviewed_by:,
          metadata: verification.metadata.to_h.merge(
            "approved_from" => "dependent_verification_center",
            "approved_at" => Time.current.iso8601
          )
        )
        verification.dependent.update!(enrollment_status: "enrolled", eligibility_status: "eligible")
      end
    end

    def reject_verification(verification, reviewed_by:, issue_code:, note:)
      DependentVerification.transaction do
        verification.update!(
          status: "rejected",
          issue_code:,
          note:,
          reviewed_at: Time.current,
          reviewed_by:,
          metadata: verification.metadata.to_h.merge(
            "rejected_from" => "dependent_verification_center",
            "rejected_at" => Time.current.iso8601
          )
        )
        verification.dependent.update!(eligibility_status: "needs_review")
      end
    end

    def generate_packet(requested_by:)
      dependent_records = dependents.to_a
      ready, holdback_dependents = dependent_records.partition { |dependent| approved_verification?(dependent) && dependent.eligible? }
      holdbacks = holdback_dependents.map { |dependent| holdback_line(dependent) }
      packet = {
        "packet_id" => "dependent_verification_#{@employer.id}_#{Time.current.to_i}",
        "generated_at" => Time.current.iso8601,
        "requested_by" => requested_by,
        "employer_id" => @employer.id,
        "status" => holdbacks.any? ? "needs_review" : "ready",
        "totals" => {
          "dependent_count" => dependent_records.count,
          "ready_count" => ready.count,
          "holdback_count" => holdbacks.count
        },
        "dependents" => ready.map { |dependent| dependent_line(dependent) },
        "holdbacks" => holdbacks
      }

      @employer.update!(settings: @employer.settings.to_h.merge(PACKET_KEY => packet))
      packet
    end

    def primary_verification(dependent)
      dependent.dependent_verifications.max_by(&:created_at)
    end

    private

    def approved_verification?(dependent)
      dependent.dependent_verifications.any?(&:approved?)
    end

    def verification_type_for(dependent)
      dependent.relationship.in?([ "child", "step_child" ]) ? "birth_certificate" : "relationship_proof"
    end

    def latest_benefits_document(dependent)
      dependent.employee.employee_documents
        .select { |document| document.document_type == "benefits" }
        .max_by(&:created_at)
    end

    def verification_status_for(dependent)
      document = latest_benefits_document(dependent)
      return "needs_review" if document&.complete?

      "requested"
    end

    def dependent_line(dependent)
      verification = primary_verification(dependent)
      {
        "dependent_id" => dependent.id,
        "dependent_name" => dependent.full_name,
        "employee_id" => dependent.employee_id,
        "employee_name" => dependent.employee.full_name,
        "relationship" => dependent.relationship,
        "remote_dependent_id" => dependent.vitable_id.presence || "pending_dependent_#{dependent.id}",
        "verification_type" => verification&.verification_type || verification_type_for(dependent),
        "status" => "ready"
      }
    end

    def holdback_line(dependent)
      verification = primary_verification(dependent)
      reason_code, reason = holdback_reason(dependent, verification)
      {
        "dependent_id" => dependent.id,
        "dependent_name" => dependent.full_name,
        "employee_name" => dependent.employee.full_name,
        "status" => verification&.status || dependent.eligibility_status,
        "reason_code" => reason_code,
        "reason" => reason
      }
    end

    def holdback_reason(dependent, verification)
      return [ "missing_verification", "Dependent verification has not been requested." ] unless verification
      return [ "verification_rejected", verification.note.presence || "Dependent verification was rejected." ] if verification.rejected?
      return [ "document_missing", "Benefits verification document has not been attached." ] if verification.employee_document.blank?
      return [ "document_incomplete", "Benefits verification document is not complete." ] unless verification.employee_document.complete?
      return [ "eligibility_review", "Dependent eligibility status is #{dependent.eligibility_status}." ] unless dependent.eligible?

      [ "verification_pending", "Dependent verification is waiting on benefits review." ]
    end
  end
end
