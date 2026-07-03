class CompensationChangesController < ApplicationController
  def show
    @changes = Compensation::ChangesQuery.new.call
  end

  def approve
    dto = Compensation::ApproveChangeDto.from_params(params)
    result = Compensation::ApproveChangeCommand.new(dto:).call

    redirect_to compensation_changes_path, notice: result.success? ? "Compensation change approved." : result.errors.to_sentence
  end

  def reject
    dto = Compensation::RejectChangeDto.from_params(params)
    result = Compensation::RejectChangeCommand.new(dto:).call

    redirect_to compensation_changes_path, notice: result.success? ? "Compensation change rejected." : result.errors.to_sentence
  end

  def apply
    dto = Compensation::ApplyChangeDto.from_params(params)
    result = Compensation::ApplyChangeCommand.new(dto:).call

    redirect_to compensation_changes_path, notice: result.success? ? "Compensation change applied." : result.errors.to_sentence
  end

  def generate_packet
    dto = Compensation::GenerateChangePacketDto.from_params(params)
    result = Compensation::GenerateChangePacketCommand.new(dto:).call

    redirect_to compensation_changes_path, notice: result.success? ? "Compensation change packet generated." : result.errors.to_sentence
  end
end
