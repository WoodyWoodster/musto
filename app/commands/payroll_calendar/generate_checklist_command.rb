module PayrollCalendar
  class GenerateChecklistCommand < ApplicationCommand
    def initialize(dto:, employer_repository: Employers::EmployerRepository.new)
      @dto = dto
      @employer = employer_repository.first_for_operations
      @repository = CalendarRepository.new(employer: @employer)
    end

    def call
      return failure(errors: "No employer is available for payroll calendar generation") unless @employer

      batch = @repository.generate_checklist(requested_by: @dto.requested_by)
      success(record: @repository.current_run, value: batch)
    rescue ActiveRecord::RecordInvalid => e
      failure(record: e.record, errors: e.record.errors.full_messages)
    end
  end
end
