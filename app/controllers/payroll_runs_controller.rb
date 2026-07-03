class PayrollRunsController < ApplicationController
  def finalize
    payroll_run = PayrollRun.find(params[:id])
    result = Payroll::FinalizeRunCommand.new(payroll_run:).call

    redirect_to payroll_path, notice: result.success? ? "Payroll run finalized." : result.errors.to_sentence
  end
end
