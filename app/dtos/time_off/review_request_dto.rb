module TimeOff
  ReviewRequestDto = Data.define(:request_id, :decision) do
    def self.from_params(params, decision:)
      new(request_id: ApplicationDto.id_from(params), decision:)
    end
  end
end
