module Compensation
  RejectChangeDto = Data.define(:change_id, :reviewed_by, :reason) do
    def self.from_params(params)
      attributes = ApplicationDto.coerce_hash(params)

      new(
        change_id: attributes.fetch(:id, attributes.fetch("id")).to_i,
        reviewed_by: attributes.fetch("reviewed_by", "ops_console"),
        reason: attributes.fetch("reason", "Rejected from compensation change review")
      )
    end
  end
end
