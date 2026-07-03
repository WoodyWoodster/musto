module Compensation
  class ApproveChangeCommand < ApplicationCommand
    def initialize(dto:, employer_repository: Employers::EmployerRepository.new, repository: nil)
      @dto = dto
      @employer = employer_repository.first_for_operations
      @repository = repository || ChangesRepository.new(employer: @employer)
    end

    def call
      return failure(errors: "No employer is available for compensation change approval") unless @employer

      change = @repository.find_change(@dto.change_id)
      return failure(record: change, errors: "Compensation change is not approvable") unless @repository.approve_change(change, approved_by: @dto.approved_by)

      success(record: change)
    rescue ActiveRecord::RecordNotFound
      failure(errors: "Compensation change was not found")
    rescue ActiveRecord::RecordInvalid => e
      failure(record: e.record, errors: e.record.errors.full_messages)
    end
  end
end
