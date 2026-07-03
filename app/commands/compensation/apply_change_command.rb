module Compensation
  class ApplyChangeCommand < ApplicationCommand
    def initialize(dto:, employer_repository: Employers::EmployerRepository.new, repository: nil)
      @dto = dto
      @employer = employer_repository.first_for_operations
      @repository = repository || ChangesRepository.new(employer: @employer)
    end

    def call
      return failure(errors: "No employer is available for compensation change apply") unless @employer

      change = @repository.find_change(@dto.change_id)
      return failure(record: change, errors: "Compensation change must be approved before apply") unless @repository.apply_change(change, applied_by: @dto.applied_by)

      success(record: change.reload)
    rescue ActiveRecord::RecordNotFound
      failure(errors: "Compensation change was not found")
    rescue ActiveRecord::RecordInvalid => e
      failure(record: e.record, errors: e.record.errors.full_messages)
    end
  end
end
