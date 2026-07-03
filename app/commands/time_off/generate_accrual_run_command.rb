module TimeOff
  class GenerateAccrualRunCommand < ApplicationCommand
    def initialize(dto:, employer_repository: Employers::EmployerRepository.new, repository: nil)
      @dto = dto
      @employer = employer_repository.first_for_operations
      @repository = repository || AccrualRepository.new(employer: @employer)
    end

    def call
      return failure(errors: "No employer is available for PTO accrual generation") unless @employer

      accruals = @repository.generate_monthly_accruals(period_start_on: @dto.period_start_on, requested_by: @dto.requested_by)
      success(record: @employer, value: accruals)
    rescue ActiveRecord::RecordInvalid => e
      failure(record: e.record, errors: e.record.errors.full_messages)
    end
  end
end
