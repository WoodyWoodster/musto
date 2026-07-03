module Garnishments
  PauseOrderDto = Data.define(:id, :paused_by, :reason) do
    def self.from_params(params)
      attributes = ApplicationDto.coerce_hash(params)

      new(
        id: attributes.fetch(:id) { attributes.fetch("id") }.to_i,
        paused_by: attributes.fetch("paused_by", "ops_console"),
        reason: attributes.fetch("reason", "Paused from garnishment center")
      )
    end
  end
end
