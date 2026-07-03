module Compensation
  ApproveChangeDto = Data.define(:change_id, :approved_by) do
    def self.from_params(params)
      attributes = ApplicationDto.coerce_hash(params)

      new(
        change_id: attributes.fetch(:id, attributes.fetch("id")).to_i,
        approved_by: attributes.fetch("approved_by", "ops_console")
      )
    end
  end
end
