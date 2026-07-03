module Operations
  class PayrollQuery
    def initialize(employer_repository: Employers::EmployerRepository.new)
      @employer = employer_repository.first_for_operations
      @repository = Payroll::PayrollRepository.new(employer: @employer)
    end

    def call
      runs = @repository.runs.map { |run| PayrollRunDto.from_record(run) }

      {
        employer: EmployerContextDto.from_record(@employer),
        payroll_runs: runs,
        current_run: runs.first,
        adjustments: @repository.adjustments.map { |adjustment| PayrollAdjustmentDto.from_record(adjustment) },
        deductions: @repository.deductions.map { |deduction| PayrollDeductionDto.from_record(deduction) }
      }
    end
  end
end
