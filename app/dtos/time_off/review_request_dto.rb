module TimeOff
  ReviewRequestDto = Data.define(:request_id, :decision, :return_to) do
    def self.from_params(params, decision:)
      attributes = ApplicationDto.coerce_hash(params)

      new(
        request_id: ApplicationDto.id_from(params),
        decision:,
        return_to: attributes["return_to"] || attributes[:return_to]
      )
    end
  end
end
