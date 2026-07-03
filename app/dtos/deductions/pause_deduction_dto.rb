module Deductions
  PauseDeductionDto = Data.define(:id, :paused_by, :reason) do
    def self.from_params(params)
      raw = ApplicationDto.coerce_hash(params)

      new(
        id: raw.fetch("id").to_i,
        paused_by: raw.fetch("paused_by", "ops_console"),
        reason: raw.fetch("reason", "Paused from payroll deduction center")
      )
    end
  end
end
