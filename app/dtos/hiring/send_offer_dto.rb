module Hiring
  SendOfferDto = Data.define(:candidate_id, :offered_by) do
    def self.from_params(params)
      attributes = ApplicationDto.coerce_hash(params)

      new(
        candidate_id: ApplicationDto.id_from(params),
        offered_by: attributes.fetch("offered_by", "ops_console")
      )
    end
  end
end
