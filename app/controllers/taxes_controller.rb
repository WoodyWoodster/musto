class TaxesController < ApplicationController
  def show
    @taxes = Taxes::CenterQuery.new.call
  end

  def generate_packet
    dto = Taxes::GeneratePacketDto.from_params(params)
    result = Taxes::GeneratePacketCommand.new(dto:).call

    redirect_to taxes_path, notice: result.success? ? "Tax filing packet generated." : result.errors.to_sentence
  end
end
