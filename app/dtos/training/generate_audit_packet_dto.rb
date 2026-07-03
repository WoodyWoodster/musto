module Training
  GenerateAuditPacketDto = Data.define(:requested_by) do
    def self.from_params(params)
      new(requested_by: ApplicationDto.coerce_hash(params).fetch("requested_by", "ops_console"))
    end
  end
end
