module Onboarding
  class CompleteTaskCommand < ApplicationCommand
    def initialize(dto:, repository: TaskRepository.new)
      @dto = dto
      @repository = repository
    end

    def call
      task = @repository.find(@dto.task_id)
      @repository.complete(task)
      refresh_employee_status(task)

      success(record: task)
    rescue ActiveRecord::RecordInvalid => e
      failure(record: e.record, errors: e.record.errors.full_messages)
    end

    private

    def refresh_employee_status(task)
      employee = task.employee

      employee.update!(onboarding_status: @repository.ready_for_completion?(employee) ? "complete" : "in_progress")
    end
  end
end
