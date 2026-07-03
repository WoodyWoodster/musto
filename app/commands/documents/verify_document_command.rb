module Documents
  class VerifyDocumentCommand < ApplicationCommand
    def initialize(dto:, repository: DocumentRepository.new)
      @dto = dto
      @repository = repository
    end

    def call
      document = @repository.find_document(@dto.document_id)
      @repository.verify_document(document, reviewed_by: @dto.reviewed_by)

      success(record: document)
    rescue ActiveRecord::RecordInvalid => e
      failure(record: e.record, errors: e.record.errors.full_messages)
    rescue ActiveRecord::RecordNotFound => e
      failure(errors: e.message)
    end
  end
end
