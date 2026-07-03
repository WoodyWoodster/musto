module Compensation
  class RejectChangeCommand < ApplicationCommand
    def initialize(dto:, employer_repository: Employers::EmployerRepository.new, repository: nil)
      @dto = dto
      @employer = employer_repository.first_for_operations
      @repository = repository || ChangesRepository.new(employer: @employer)
    end

    def call
      return failure(errors: "No employer is available for compensation change rejection") unless @employer

      change = @repository.find_change(@dto.change_id)
      return failure(record: change, errors: "Applied compensation changes cannot be rejected") unless @repository.reject_change(change, reviewed_by: @dto.reviewed_by, reason: @dto.reason)

      success(record: change)
    rescue ActiveRecord::RecordNotFound
      failure(errors: "Compensation change was not found")
    rescue ActiveRecord::RecordInvalid => e
      failure(record: e.record, errors: e.record.errors.full_messages)
    end
  end
end
