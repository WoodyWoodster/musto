class TimeOffAccrualsController < ApplicationController
  def show
    @accruals = TimeOff::AccrualLedgerQuery.new.call
  end

  def generate_run
    dto = TimeOff::GenerateAccrualRunDto.from_params(params)
    result = TimeOff::GenerateAccrualRunCommand.new(dto:).call

    redirect_to time_off_accruals_path, notice: result.success? ? "PTO accrual run generated." : result.errors.to_sentence
  end

  def approve
    dto = TimeOff::ApproveAccrualDto.from_params(params)
    result = TimeOff::ApproveAccrualCommand.new(dto:).call

    redirect_to time_off_accruals_path, notice: result.success? ? "PTO accrual approved." : result.errors.to_sentence
  end

  def generate_packet
    dto = TimeOff::GenerateAccrualPayrollPacketDto.from_params(params)
    result = TimeOff::GenerateAccrualPayrollPacketCommand.new(dto:).call

    redirect_to time_off_accruals_path, notice: result.success? ? "PTO payroll packet generated." : result.errors.to_sentence
  end
end
