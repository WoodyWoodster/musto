class VitableEmbeddedSessionsController < ApplicationController
  def show
    @sessions = Vitable::EmbeddedSessionsQuery.new.call
  end

  def generate_packet
    dto = Vitable::GenerateEmbeddedSessionsDto.from_params(params)
    result = Vitable::GenerateEmbeddedSessionsCommand.new(dto:).call

    redirect_to vitable_embedded_sessions_path, notice: result.success? ? "Embedded enrollment session packet generated." : result.errors.to_sentence
  end

  def issue
    dto = Vitable::IssueEmbeddedSessionDto.from_params(params)
    result = Vitable::IssueEmbeddedSessionCommand.new(dto:).call

    redirect_to vitable_embedded_sessions_path, notice: result.success? ? "Employee-bound Vitable session issued." : result.errors.to_sentence
  end
end
