module Benefits
  class BenefitsRepository < ApplicationRepository
    def initialize(employer:)
      @employer = employer
    end

    def plans
      return BenefitPlan.none unless @employer

      @employer.benefit_plans.includes(:enrollments).order(:category, :name)
    end

    def enrollments
      Enrollment
        .joins(:employee)
        .where(employees: { employer_id: @employer&.id })
        .includes(:employee, :benefit_plan)
        .order(created_at: :desc)
    end

    def accepted_enrollment_count
      enrollments.accepted.count
    end

    def pending_enrollment_count
      enrollments.pending.count
    end
  end
end
