module Deductions
  ApproveDeductionDto = Data.define(:id, :approved_by) do
    def self.from_params(params)
      raw = ApplicationDto.coerce_hash(params)

      new(
        id: raw.fetch("id").to_i,
        approved_by: raw.fetch("approved_by", "ops_console")
      )
    end
  end
end
