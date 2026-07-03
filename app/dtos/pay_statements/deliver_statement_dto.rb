module PayStatements
  DeliverStatementDto = Data.define(:statement_id, :delivered_by) do
    def self.from_params(params)
      attributes = ApplicationDto.coerce_hash(params)

      new(
        statement_id: ApplicationDto.id_from(params),
        delivered_by: attributes.fetch("delivered_by", "ops_console")
      )
    end
  end
end
