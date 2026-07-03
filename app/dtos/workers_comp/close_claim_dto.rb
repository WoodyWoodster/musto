module WorkersComp
  CloseClaimDto = Data.define(:id, :closed_by, :resolution) do
    def self.from_params(params)
      attributes = ApplicationDto.coerce_hash(params)

      new(
        id: attributes.fetch(:id) { attributes.fetch("id") }.to_i,
        closed_by: attributes.fetch("closed_by", "compliance_ops"),
        resolution: attributes.fetch("resolution", "Closed from workers comp center")
      )
    end
  end
end
