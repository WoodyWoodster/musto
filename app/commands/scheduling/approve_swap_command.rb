module Scheduling
  class ApproveSwapCommand < ApplicationCommand
    def initialize(dto:, employer_repository: Employers::EmployerRepository.new, repository: nil)
      @dto = dto
      @employer = employer_repository.first_for_operations
      @repository = repository || ScheduleRepository.new(employer: @employer)
    end

    def call
      return failure(errors: "No employer is available for shift swap approval") unless @employer

      swap = @repository.find_swap(@dto.id)
      return failure(record: swap, errors: "Shift swap is not reviewable") unless @repository.approve_swap(swap, reviewed_by: @dto.reviewed_by)

      success(record: swap)
    rescue ActiveRecord::RecordNotFound
      failure(errors: "Shift swap request was not found")
    rescue ActiveRecord::RecordInvalid => e
      failure(record: e.record, errors: e.record.errors.full_messages)
    end
  end
end
