module Onboarding
  class CompleteTaskCommand < ApplicationCommand
    def initialize(task:)
      @task = task
    end

    def call
      @task.update!(status: "complete", completed_at: Time.current)
      refresh_employee_status

      success(record: @task)
    rescue ActiveRecord::RecordInvalid => e
      failure(record: @task, errors: e.record.errors.full_messages)
    end

    private

    def refresh_employee_status
      employee = @task.employee
      return if employee.onboarding_tasks.open.exists?

      employee.update!(onboarding_status: "complete")
    end
  end
end
