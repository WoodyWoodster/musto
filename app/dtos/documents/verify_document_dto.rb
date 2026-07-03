module Documents
  VerifyDocumentDto = Data.define(:document_id, :reviewed_by) do
    def self.from_params(params)
      attributes = ApplicationDto.coerce_hash(params)

      new(
        document_id: ApplicationDto.id_from(params),
        reviewed_by: attributes.fetch("reviewed_by", "ops_console")
      )
    end
  end
end
