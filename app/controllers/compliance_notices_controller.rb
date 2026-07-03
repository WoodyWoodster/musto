class ComplianceNoticesController < ApplicationController
  def show
    @notices = Compliance::NoticeCenterQuery.new.call
  end

  def acknowledge
    dto = Compliance::AcknowledgeNoticeDto.from_params(params)
    result = Compliance::AcknowledgeNoticeCommand.new(dto:).call

    redirect_to compliance_notices_path, notice: result.success? ? "Compliance notice acknowledged." : result.errors.to_sentence
  end

  def resolve
    dto = Compliance::ResolveNoticeDto.from_params(params)
    result = Compliance::ResolveNoticeCommand.new(dto:).call

    redirect_to compliance_notices_path, notice: result.success? ? "Compliance notice resolved." : result.errors.to_sentence
  end

  def generate_packet
    dto = Compliance::GenerateNoticePacketDto.from_params(params)
    result = Compliance::GenerateNoticePacketCommand.new(dto:).call

    redirect_to compliance_notices_path, notice: result.success? ? "Compliance notice packet generated." : result.errors.to_sentence
  end
end
