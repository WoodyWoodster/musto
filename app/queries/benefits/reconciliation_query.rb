module Benefits
  class ReconciliationQuery
    def initialize(employer_repository: Employers::EmployerRepository.new)
      @employer = employer_repository.first_for_operations
      @repository = BenefitsRepository.new(employer: @employer)
    end

    def call
      ReconciliationDetailDto.from_records(
        employer: @employer,
        payroll_run: @repository.current_payroll_run,
        enrollments: @repository.reconciliation_enrollments
      )
    end
  end
end
