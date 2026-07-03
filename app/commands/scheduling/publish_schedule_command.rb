module Scheduling
  class PublishScheduleCommand < ApplicationCommand
    def initialize(dto:, employer_repository: Employers::EmployerRepository.new, repository: nil)
      @dto = dto
      @employer = employer_repository.first_for_operations
      @repository = repository || ScheduleRepository.new(employer: @employer)
    end

    def call
      return failure(errors: "No employer is available for schedule publishing") unless @employer

      shifts = @repository.publish_schedule(published_by: @dto.published_by)
      success(record: @employer, value: shifts)
    rescue ActiveRecord::RecordInvalid => e
      failure(record: e.record, errors: e.record.errors.full_messages)
    end
  end
end
