class VitableAdminSessionsController < ApplicationController
  def show
    @admin_sessions = Vitable::AdminSessionsQuery.new.call
  end

  def generate_packet
    dto = Vitable::GenerateAdminSessionsDto.from_params(params)
    result = Vitable::GenerateAdminSessionsCommand.new(dto:).call

    redirect_to vitable_admin_sessions_path, notice: result.success? ? "Employer admin session packet generated." : result.errors.to_sentence
  end

  def issue
    dto = Vitable::IssueAdminSessionDto.from_params(params)
    result = Vitable::IssueAdminSessionCommand.new(dto:).call

    redirect_to vitable_admin_sessions_path, notice: result.success? ? "Employer-bound Vitable admin session issued." : result.errors.to_sentence
  end
end
