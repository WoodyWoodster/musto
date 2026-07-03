module Expenses
  class GenerateReimbursementBatchCommand < ApplicationCommand
    def initialize(dto:, employer_repository: Employers::EmployerRepository.new)
      @dto = dto
      @employer = employer_repository.first_for_operations
      @repository = ExpenseRepository.new(employer: @employer)
    end

    def call
      return failure(errors: "No employer is available for reimbursement batching") unless @employer

      batch = @repository.generate_reimbursement_batch(requested_by: @dto.requested_by)
      success(record: @employer.reload, value: batch)
    rescue ActiveRecord::RecordInvalid => e
      failure(record: e.record, errors: e.record.errors.full_messages)
    end
  end
end
