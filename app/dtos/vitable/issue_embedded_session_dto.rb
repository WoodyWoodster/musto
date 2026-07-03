module Vitable
  IssueEmbeddedSessionDto = Data.define(:employee_id, :requested_by) do
    def self.from_params(params)
      attributes = ApplicationDto.coerce_hash(params)

      new(
        employee_id: attributes.fetch("employee_id").to_i,
        requested_by: attributes.fetch("requested_by", "ops_console")
      )
    end
  end
end
