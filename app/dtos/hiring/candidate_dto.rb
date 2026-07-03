module Hiring
  CandidateDto = Data.define(:id, :job_opening_id, :employee_id, :candidate_name, :email, :phone, :source, :stage, :score, :applied_on, :target_start_on, :compensation_cents, :offer_sent_at, :accepted_at, :hired_at, :job_title, :department_name, :location_name, :readiness_status, :readiness_reason) do
    def self.from_record(record)
      opening = record.job_opening

      new(
        id: record.id,
        job_opening_id: record.job_opening_id,
        employee_id: record.employee_id,
        candidate_name: record.full_name,
        email: record.email,
        phone: record.phone,
        source: record.source,
        stage: record.stage,
        score: record.score,
        applied_on: record.applied_on,
        target_start_on: record.target_start_on,
        compensation_cents: record.compensation_cents,
        offer_sent_at: record.offer_sent_at,
        accepted_at: record.accepted_at,
        hired_at: record.hired_at,
        job_title: opening.title,
        department_name: opening.department&.name,
        location_name: opening.work_location&.name,
        readiness_status: readiness_status(record),
        readiness_reason: readiness_reason(record)
      )
    end

    def offerable?
      stage.in?(%w[applied screening interview])
    end

    def accepted?
      stage == "accepted"
    end

    def self.readiness_status(record)
      return "ready" if record.accepted? && record.employee_id.blank?
      return "complete" if record.hired?
      return "needs_review" if record.stage == "offer"
      return "blocked" if record.stage.in?(%w[rejected withdrawn])

      "in_progress"
    end

    def self.readiness_reason(record)
      return "Ready to create onboarding and payroll setup" if record.accepted? && record.employee_id.blank?
      return "Employee record already created" if record.employee_id.present?
      return "Offer is waiting for candidate acceptance" if record.stage == "offer"
      return "Candidate is no longer active" if record.stage.in?(%w[rejected withdrawn])

      "Move through interview and offer review"
    end

    private_class_method :readiness_status, :readiness_reason
  end
end
