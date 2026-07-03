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

    redirect_to redirect_path(dto), notice: result.success? ? "Time off #{decision}." : result.errors.to_sentence
  end

  def redirect_path(dto)
    dto.return_to == "time_off" ? time_off_path : compliance_path
  end
end
