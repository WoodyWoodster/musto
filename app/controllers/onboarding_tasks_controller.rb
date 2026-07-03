class OnboardingTasksController < ApplicationController
  def complete
    dto = Onboarding::CompleteTaskDto.from_params(params)
    result = Onboarding::CompleteTaskCommand.new(dto:).call

    redirect_to workforce_path, notice: result.success? ? "Onboarding task completed." : result.errors.to_sentence
  end
end
