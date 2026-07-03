module Scheduling
  ApproveSwapDto = Data.define(:id, :reviewed_by) do
    def self.from_params(params)
      raw = ApplicationDto.coerce_hash(params)

      new(
        id: raw.fetch("id").to_i,
        reviewed_by: raw.fetch("reviewed_by", "ops_console")
      )
    end
  end
end
