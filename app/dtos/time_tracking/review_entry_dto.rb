module TimeTracking
  ReviewEntryDto = Data.define(:entry_id, :decision, :return_to, :reviewed_by) do
    def self.from_params(params, decision:)
      attributes = ApplicationDto.coerce_hash(params)

      new(
        entry_id: ApplicationDto.id_from(params),
        decision: decision,
        return_to: attributes["return_to"] || attributes[:return_to],
        reviewed_by: attributes.fetch("reviewed_by", "ops_console")
      )
    end
  end
end
