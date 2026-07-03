module TimeTracking
  class GenerateExportCommand < ApplicationCommand
    def initialize(dto:, employer_repository: Employers::EmployerRepository.new)
      @dto = dto
      @employer = employer_repository.first_for_operations
      @repository = TimeTrackingRepository.new(employer: @employer)
    end

    def call
      return failure(errors: "No employer is available for time tracking export") unless @employer

      export = @repository.generate_payroll_export(requested_by: @dto.requested_by)
      success(record: @employer.reload, value: export)
    rescue ActiveRecord::RecordInvalid => e
      failure(record: e.record, errors: e.record.errors.full_messages)
    end
  end
end
