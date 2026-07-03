module Onboarding
  class TaskRepository < ApplicationRepository
    def find(id)
      OnboardingTask.includes(:employee).find(id)
    end

    def complete(task)
      task.update!(status: "complete", completed_at: Time.current)
      task
    end

    def open_for_employee?(employee)
      employee.onboarding_tasks.open.exists?
    end

    def ready_for_completion?(employee)
      !employee.onboarding_tasks.open.exists? && !employee.employee_documents.attention_needed.exists?
    end
  end
end
