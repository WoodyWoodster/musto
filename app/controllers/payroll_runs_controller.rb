class PayrollRunsController < ApplicationController
  def finalize
    dto = Payroll::FinalizeRunDto.from_params(params)
    result = Payroll::FinalizeRunCommand.new(dto:).call

    redirect_to payroll_path, notice: result.success? ? "Payroll run finalized." : result.errors.to_sentence
  end
end
