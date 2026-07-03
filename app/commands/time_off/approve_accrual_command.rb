module TimeOff
  class ApproveAccrualCommand < ApplicationCommand
    def initialize(dto:, employer_repository: Employers::EmployerRepository.new, repository: nil)
      @dto = dto
      @employer = employer_repository.first_for_operations
      @repository = repository || AccrualRepository.new(employer: @employer)
    end

    def call
      return failure(errors: "No employer is available for PTO accrual approval") unless @employer

      accrual = @repository.find_accrual(@dto.accrual_id)
      @repository.approve_accrual(accrual, approved_by: @dto.approved_by)
      success(record: accrual.reload)
    rescue ActiveRecord::RecordNotFound
      failure(errors: "PTO accrual was not found")
    rescue ActiveRecord::RecordInvalid => e
      failure(record: e.record, errors: e.record.errors.full_messages)
    end
  end
end
