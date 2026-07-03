module Deductions
  class ApproveDeductionCommand < ApplicationCommand
    def initialize(dto:, employer_repository: Employers::EmployerRepository.new, repository: nil)
      @dto = dto
      @employer = employer_repository.first_for_operations
      @repository = repository || DeductionRepository.new(employer: @employer)
    end

    def call
      return failure(errors: "No employer is available for deduction approval") unless @employer

      deduction = @repository.find_deduction(@dto.id)
      return failure(record: deduction, errors: "Deduction order is not approvable") unless @repository.approve_deduction(deduction, approved_by: @dto.approved_by)

      success(record: deduction)
    rescue ActiveRecord::RecordNotFound
      failure(errors: "Deduction order was not found")
    rescue ActiveRecord::RecordInvalid => e
      failure(record: e.record, errors: e.record.errors.full_messages)
    end
  end
end
