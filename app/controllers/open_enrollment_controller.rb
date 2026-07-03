class OpenEnrollmentController < ApplicationController
  def show
    @open_enrollment = OpenEnrollment::CenterQuery.new.call
  end

  def launch
    dto = OpenEnrollment::LaunchCampaignDto.from_params(params)
    result = OpenEnrollment::LaunchCampaignCommand.new(dto:).call

    redirect_to benefits_open_enrollment_path, notice: result.success? ? "Open enrollment campaign launched." : result.errors.to_sentence
  end

  def send_reminders
    dto = OpenEnrollment::SendRemindersDto.from_params(params)
    result = OpenEnrollment::SendRemindersCommand.new(dto:).call

    redirect_to benefits_open_enrollment_path, notice: result.success? ? "Open enrollment reminders sent." : result.errors.to_sentence
  end
end
