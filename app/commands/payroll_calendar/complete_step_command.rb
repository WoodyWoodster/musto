module PayrollCalendar
  class CompleteStepCommand < ApplicationCommand
    def initialize(dto:, repository: CalendarRepository.new)
      @dto = dto
      @repository = repository
    end

    def call
      step = @repository.find_step(@dto.approval_step_id)
      return failure(record: step, errors: "Blocked payroll approval steps must be resolved before completion") if step.blocked?

      @repository.complete_step(step, completed_by: @dto.completed_by)
      success(record: step)
    rescue ActiveRecord::RecordNotFound
      failure(errors: "Payroll approval step was not found")
    rescue ActiveRecord::RecordInvalid => e
      failure(record: e.record, errors: e.record.errors.full_messages)
    end
  end
end
