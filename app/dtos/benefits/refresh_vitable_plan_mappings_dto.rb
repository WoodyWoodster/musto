module Benefits
  RefreshVitablePlanMappingsDto = Data.define(:requested_by) do
    def self.from_params(params)
      attributes = ApplicationDto.coerce_hash(params)

      new(requested_by: attributes.fetch("requested_by", "benefits_admin"))
    end
  end
end
