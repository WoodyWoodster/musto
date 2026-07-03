class CompanySetupController < ApplicationController
  def show
    @company_setup = Company::SetupQuery.new.call
  end

  def complete_step
    dto = Company::CompleteSetupStepDto.from_params(params)
    result = Company::CompleteSetupStepCommand.new(dto:).call

    redirect_to company_setup_path, notice: result.success? ? "Company setup step completed." : result.errors.to_sentence
  end
end
