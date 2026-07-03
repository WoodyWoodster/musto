module Onboarding
  VerifyDocumentDto = Data.define(:document_id) do
    def self.from_params(params)
      new(document_id: ApplicationDto.id_from(params))
    end
  end
end
