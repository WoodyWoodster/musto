module Benefits
  RejectDependentVerificationDto = Data.define(:verification_id, :reviewed_by, :issue_code, :note) do
    def self.from_params(params)
      attributes = ApplicationDto.coerce_hash(params)

      new(
        verification_id: attributes.fetch(:id) { attributes.fetch("id") }.to_i,
        reviewed_by: attributes.fetch(:reviewed_by) { attributes.fetch("reviewed_by", "benefits_admin") },
        issue_code: attributes.fetch(:issue_code) { attributes.fetch("issue_code", "document_mismatch") },
        note: attributes.fetch(:note) { attributes.fetch("note", "Dependent verification requires follow-up.") }
      )
    end
  end
end
