class OnboardingTasksController < ApplicationController
  def complete
    dto = Onboarding::CompleteTaskDto.from_params(params)
    result = Onboarding::CompleteTaskCommand.new(dto:).call

    redirect_to redirect_path(dto), notice: result.success? ? "Onboarding task completed." : result.errors.to_sentence
  end

  private

  def redirect_path(dto)
    dto.return_to == "onboarding" ? onboarding_path : workforce_path
  end
end
