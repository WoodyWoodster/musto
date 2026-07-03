class OnboardingTasksController < ApplicationController
  def complete
    task = OnboardingTask.find(params[:id])
    result = Onboarding::CompleteTaskCommand.new(task:).call

    redirect_to workforce_path, notice: result.success? ? "Onboarding task completed." : result.errors.to_sentence
  end
end
