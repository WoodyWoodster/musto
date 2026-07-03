class PayrollDeductionsController < ApplicationController
  def show
    @deductions = Deductions::CenterQuery.new.call
  end

  def approve
    dto = Deductions::ApproveDeductionDto.from_params(params)
    result = Deductions::ApproveDeductionCommand.new(dto:).call

    redirect_to payroll_deductions_center_path, notice: result.success? ? "Deduction order approved." : result.errors.to_sentence
  end

  def pause
    dto = Deductions::PauseDeductionDto.from_params(params)
    result = Deductions::PauseDeductionCommand.new(dto:).call

    redirect_to payroll_deductions_center_path, notice: result.success? ? "Deduction order paused." : result.errors.to_sentence
  end

  def generate_packet
    dto = Deductions::GeneratePacketDto.from_params(params)
    result = Deductions::GeneratePacketCommand.new(dto:).call

    redirect_to payroll_deductions_center_path, notice: result.success? ? "Deduction packet generated." : result.errors.to_sentence
  end
end
