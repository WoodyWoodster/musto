class ComplianceCasesController < ApplicationController
  def resolve
    dto = Compliance::ResolveCaseDto.from_params(params)
    result = Compliance::ResolveCaseCommand.new(dto:).call

    redirect_to compliance_path, notice: result.success? ? "Compliance case resolved." : result.errors.to_sentence
  end
end
