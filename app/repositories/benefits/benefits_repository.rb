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

    def find(id)
      Enrollment.find(id)
    end

    def find_detail(id)
      Enrollment
        .includes(
          :benefit_plan,
          employee: [ :department, :work_location, employer: [ :organization ] ],
          payroll_deductions: [ :payroll_run, :employee, enrollment: [ :benefit_plan ] ],
        )
        .find(id)
    end

    def review_enrollment(enrollment, decision)
      Enrollment.transaction do
        enrollment.update!(
          status: decision,
          accepted_at: decision == "accepted" ? Time.current : nil,
          effective_on: enrollment.effective_on || Date.current.beginning_of_month.next_month
        )
        sync_payroll_deductions(enrollment, decision)
      end

      enrollment
    end

    private

    def sync_payroll_deductions(enrollment, decision)
      enrollment.payroll_deductions.find_each do |deduction|
        if decision == "accepted"
          deduction.update!(amount_cents: enrollment.benefit_plan.monthly_premium_cents, status: "ready")
        else
          deduction.update!(amount_cents: 0, status: "waived")
        end
      end
    end
  end
end
