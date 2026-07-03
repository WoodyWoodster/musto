class ContractorsController < ApplicationController
  def show
    @contractors = Contractors::CenterQuery.new.call
  end

  def approve_payment
    dto = Contractors::ApprovePaymentDto.from_params(params)
    result = Contractors::ApprovePaymentCommand.new(dto:).call

    redirect_to contractors_path, notice: result.success? ? "Contractor payment approved." : result.errors.to_sentence
  end

  def generate_batch
    dto = Contractors::GenerateBatchDto.from_params(params)
    result = Contractors::GeneratePaymentBatchCommand.new(dto:).call

    redirect_to contractors_path, notice: result.success? ? "Contractor payment batch generated." : result.errors.to_sentence
  end
end
