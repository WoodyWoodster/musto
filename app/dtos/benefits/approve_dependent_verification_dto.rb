module Benefits
  ApproveDependentVerificationDto = Data.define(:verification_id, :reviewed_by) do
    def self.from_params(params)
      attributes = ApplicationDto.coerce_hash(params)

      new(
        verification_id: attributes.fetch(:id) { attributes.fetch("id") }.to_i,
        reviewed_by: attributes.fetch(:reviewed_by) { attributes.fetch("reviewed_by", "benefits_admin") }
      )
    end
  end
end
