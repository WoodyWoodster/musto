module Operations
  class PayrollQuery
    def initialize(employer: Employer.includes(:organization).order(:created_at).first)
      @employer = employer
    end

    def call
      {
        employer: @employer,
        payroll_runs: payroll_runs.includes(:payroll_deductions, :payroll_adjustments).order(pay_date: :desc),
        current_run: payroll_runs.includes(:payroll_deductions, :payroll_adjustments).order(pay_date: :desc).first,
        adjustments: adjustments.includes(:employee).order(created_at: :desc),
        deductions: deductions.includes(:employee, :enrollment).order(created_at: :desc)
      }
    end

    private

    def payroll_runs
      return PayrollRun.none unless @employer

      @employer.payroll_runs
    end

    def adjustments
      PayrollAdjustment.joins(:payroll_run).where(payroll_runs: { employer_id: @employer&.id })
    end

    def deductions
      PayrollDeduction.joins(:payroll_run).where(payroll_runs: { employer_id: @employer&.id })
    end
  end
end
