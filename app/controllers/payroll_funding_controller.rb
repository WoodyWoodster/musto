class PayrollFundingController < ApplicationController
  def show
    @funding = PayrollFunding::CenterQuery.new.call
  end

  def verify_employee_account
    dto = PayrollFunding::VerifyEmployeeAccountDto.from_params(params)
    result = PayrollFunding::VerifyEmployeeAccountCommand.new(dto:).call

    redirect_to payroll_funding_path, notice: result.success? ? "Employee bank account verified." : result.errors.to_sentence
  end

  def generate_batch
    dto = PayrollFunding::GenerateBatchDto.from_params(params)
    result = PayrollFunding::GenerateBatchCommand.new(dto:).call

    redirect_to payroll_funding_path, notice: result.success? ? "Payroll funding ACH batch generated." : result.errors.to_sentence
  end
end
