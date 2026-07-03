module EmployeeChanges
  RejectRequestDto = Data.define(:request_id, :reviewed_by, :reason) do
    def self.from_params(params)
      attributes = ApplicationDto.coerce_hash(params)

      new(
        request_id: ApplicationDto.id_from(params),
        reviewed_by: attributes.fetch("reviewed_by", "ops_console"),
        reason: attributes.fetch("reason", "Rejected from employee self-service inbox")
      )
    end
  end
end
