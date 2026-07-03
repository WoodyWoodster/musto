class EmployeeDocumentsController < ApplicationController
  def verify
    dto = Onboarding::VerifyDocumentDto.from_params(params)
    result = Onboarding::VerifyDocumentCommand.new(dto:).call

    redirect_to onboarding_path, notice: result.success? ? "Document verified." : result.errors.to_sentence
  end
end
