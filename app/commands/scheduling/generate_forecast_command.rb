module Scheduling
  class GenerateForecastCommand < ApplicationCommand
    def initialize(dto:, employer_repository: Employers::EmployerRepository.new, repository: nil)
      @dto = dto
      @employer = employer_repository.first_for_operations
      @repository = repository || ScheduleRepository.new(employer: @employer)
    end

    def call
      return failure(errors: "No employer is available for schedule forecast") unless @employer

      forecast = @repository.generate_forecast(requested_by: @dto.requested_by)
      success(record: @employer, value: forecast)
    rescue ActiveRecord::RecordInvalid => e
      failure(record: e.record, errors: e.record.errors.full_messages)
    end
  end
end
