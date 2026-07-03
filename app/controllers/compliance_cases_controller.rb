class ComplianceCasesController < ApplicationController
  def resolve
    compliance_case = ComplianceCase.find(params[:id])
    result = Compliance::ResolveCaseCommand.new(compliance_case:).call

    redirect_to compliance_path, notice: result.success? ? "Compliance case resolved." : result.errors.to_sentence
  end
end
