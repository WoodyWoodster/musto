class EmployeeDocumentsController < ApplicationController
  def show
    @documents = Documents::CenterQuery.new.call
  end

  def request_batch
    dto = Documents::GenerateRequestBatchDto.from_params(params)
    result = Documents::GenerateRequestBatchCommand.new(dto:).call

    redirect_to documents_path, notice: result.success? ? "Employee document request batch generated." : result.errors.to_sentence
  end

  def verify
    dto = Documents::VerifyDocumentDto.from_params(params)
    result = Documents::VerifyDocumentCommand.new(dto:).call

    redirect_to document_return_path, notice: result.success? ? "Document verified." : result.errors.to_sentence
  end

  private

  def document_return_path
    params[:return_to] == "documents" ? documents_path : onboarding_path
  end
end
