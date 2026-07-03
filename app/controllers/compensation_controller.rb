class CompensationController < ApplicationController
  def show
    @compensation = Compensation::CenterQuery.new.call
  end

  def generate_packet
    dto = Compensation::GeneratePacketDto.from_params(params)
    result = Compensation::GeneratePacketCommand.new(dto:).call

    redirect_to compensation_path, notice: result.success? ? "Compensation packet generated." : result.errors.to_sentence
  end
end
