module People
  class GenerateDirectorySnapshotCommand < ApplicationCommand
    def initialize(dto:, employer_repository: Employers::EmployerRepository.new, repository: nil)
      @dto = dto
      @employer = employer_repository.first_for_operations
      @repository = repository || DirectoryRepository.new(employer: @employer)
    end

    def call
      return failure(errors: "No employer is available for people directory snapshot") unless @employer

      snapshot = @repository.generate_snapshot(requested_by: @dto.requested_by)
      success(record: @employer.reload, value: snapshot)
    rescue ActiveRecord::RecordInvalid => e
      failure(record: e.record, errors: e.record.errors.full_messages)
    end
  end
end
