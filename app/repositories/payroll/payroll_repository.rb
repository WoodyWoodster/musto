module Payroll
  class PayrollRepository < ApplicationRepository
    def initialize(employer: nil)
      @employer = employer
    end

    def runs
      return PayrollRun.none unless @employer

      @employer.payroll_runs.includes(:payroll_deductions, :payroll_adjustments).order(pay_date: :desc)
    end

    def current_run
      runs.first
    end

    def adjustments
      PayrollAdjustment
        .joins(:payroll_run)
        .where(payroll_runs: { employer_id: @employer&.id })
        .includes(:employee)
        .order(created_at: :desc)
    end

    def deductions
      PayrollDeduction
        .joins(:payroll_run)
        .where(payroll_runs: { employer_id: @employer&.id })
        .includes(:employee, enrollment: [ :benefit_plan ])
        .order(created_at: :desc)
    end

    def find_run(id)
      PayrollRun.find(id)
    end

    def find_detail(id)
      PayrollRun
        .includes(
          employer: [ :organization ],
          payroll_deductions: [ :payroll_run, :employee, { enrollment: [ :benefit_plan ] } ],
          payroll_adjustments: [ :payroll_run, :employee ]
        )
        .find(id)
    end

    def finalize(run)
      run.update!(status: "finalized")
      run
    end
  end
end
