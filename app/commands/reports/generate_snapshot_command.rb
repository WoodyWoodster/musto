module Reports
  class GenerateSnapshotCommand < ApplicationCommand
    def initialize(dto:, employer_repository: Employers::EmployerRepository.new)
      @dto = dto
      @employer = employer_repository.first_for_operations
      @repository = ReportsRepository.new(employer: @employer)
    end

    def call
      snapshot = @repository.generate_snapshot(requested_by: @dto.requested_by)
      success(record: @employer.reload, value: snapshot)
    rescue ActiveRecord::RecordInvalid => e
      failure(record: e.record, errors: e.record.errors.full_messages)
    end
  end
end
