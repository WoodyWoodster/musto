module EmployeeChanges
  class GenerateSyncBatchCommand < ApplicationCommand
    def initialize(dto:, employer_repository: Employers::EmployerRepository.new, repository: nil)
      @dto = dto
      @employer = employer_repository.first_for_operations
      @repository = repository || ChangeRequestRepository.new(employer: @employer)
    end

    def call
      return failure(errors: "No employer is available for employee change sync") unless @employer

      batch = @repository.generate_sync_batch(requested_by: @dto.requested_by)
      success(record: @employer, value: batch)
    rescue ActiveRecord::RecordInvalid => e
      failure(record: e.record, errors: e.record.errors.full_messages)
    end
  end
end
