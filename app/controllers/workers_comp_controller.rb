class WorkersCompController < ApplicationController
  def show
    @workers_comp = WorkersComp::CenterQuery.new.call
  end

  def generate_packet
    dto = WorkersComp::GenerateAuditPacketDto.from_params(params)
    result = WorkersComp::GenerateAuditPacketCommand.new(dto:).call

    redirect_to workers_comp_path, notice: result.success? ? "Workers comp audit packet generated." : result.errors.to_sentence
  end

  def close_claim
    dto = WorkersComp::CloseClaimDto.from_params(params)
    result = WorkersComp::CloseClaimCommand.new(dto:).call

    redirect_to workers_comp_path, notice: result.success? ? "Workers comp claim closed." : result.errors.to_sentence
  end
end
