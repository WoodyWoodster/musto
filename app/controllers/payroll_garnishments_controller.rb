class PayrollGarnishmentsController < ApplicationController
  def show
    @garnishments = Garnishments::CenterQuery.new.call
  end

  def generate_packet
    dto = Garnishments::GeneratePacketDto.from_params(params)
    result = Garnishments::GeneratePacketCommand.new(dto:).call

    redirect_to payroll_garnishments_path, notice: result.success? ? "Garnishment remittance packet generated." : result.errors.to_sentence
  end

  def approve
    dto = Garnishments::ApproveOrderDto.from_params(params)
    result = Garnishments::ApproveOrderCommand.new(dto:).call

    redirect_to payroll_garnishments_path, notice: result.success? ? "Garnishment order approved." : result.errors.to_sentence
  end

  def pause
    dto = Garnishments::PauseOrderDto.from_params(params)
    result = Garnishments::PauseOrderCommand.new(dto:).call

    redirect_to payroll_garnishments_path, notice: result.success? ? "Garnishment order paused." : result.errors.to_sentence
  end
end
