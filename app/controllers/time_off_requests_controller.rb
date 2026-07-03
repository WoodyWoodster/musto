class TimeOffRequestsController < ApplicationController
  def approve
    review("approved")
  end

  def deny
    review("denied")
  end

  private

  def review(decision)
    dto = TimeOff::ReviewRequestDto.from_params(params, decision:)
    result = TimeOff::ReviewRequestCommand.new(dto:).call

    redirect_to compliance_path, notice: result.success? ? "Time off #{decision}." : result.errors.to_sentence
  end
end
