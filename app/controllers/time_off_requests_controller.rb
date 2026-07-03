class TimeOffRequestsController < ApplicationController
  def approve
    review("approved")
  end

  def deny
    review("denied")
  end

  private

  def review(decision)
    request = TimeOffRequest.find(params[:id])
    result = TimeOff::ReviewRequestCommand.new(request:, decision:).call

    redirect_to compliance_path, notice: result.success? ? "Time off #{decision}." : result.errors.to_sentence
  end
end
