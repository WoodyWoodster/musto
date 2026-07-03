class PayrollRunsController < ApplicationController
  def show
    @payroll_run = Payroll::RunDetailQuery.new.call(params[:id])
  end

  def finalize
    dto = Payroll::FinalizeRunDto.from_params(params)
    result = Payroll::FinalizeRunCommand.new(dto:).call

    redirect_to(
      result.success? ? payroll_run_path(result.record) : payroll_path,
      notice: result.success? ? "Payroll run finalized." : result.errors.to_sentence
    )
  end
end
