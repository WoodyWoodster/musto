module Compensation
  ApplyChangeDto = Data.define(:change_id, :applied_by) do
    def self.from_params(params)
      attributes = ApplicationDto.coerce_hash(params)

      new(
        change_id: attributes.fetch(:id) { attributes.fetch("id") }.to_i,
        applied_by: attributes.fetch("applied_by", "ops_console")
      )
    end
  end
end
