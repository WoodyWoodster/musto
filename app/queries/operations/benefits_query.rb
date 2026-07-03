module Operations
  class BenefitsQuery
    def initialize(employer: Employer.includes(:organization).order(:created_at).first)
      @employer = employer
    end

    def call
      {
        employer: @employer,
        benefit_plans: benefit_plans.includes(:enrollments).order(:category, :name),
        enrollments: enrollments.includes(:employee, :benefit_plan).order(created_at: :desc),
        connections: IntegrationConnection.vitable.includes(:organization).order(created_at: :desc),
        webhooks: WebhookEvent.order(created_at: :desc).limit(12)
      }
    end

    private

    def benefit_plans
      return BenefitPlan.none unless @employer

      @employer.benefit_plans
    end

    def enrollments
      Enrollment.joins(:employee).where(employees: { employer_id: @employer&.id })
    end
  end
end
