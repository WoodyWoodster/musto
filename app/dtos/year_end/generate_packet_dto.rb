module YearEnd
  GeneratePacketDto = Data.define(:requested_by, :tax_year) do
    def self.from_params(params)
      attributes = ApplicationDto.coerce_hash(params)

      new(
        requested_by: attributes.fetch("requested_by", "ops_console"),
        tax_year: attributes.fetch("tax_year", Date.current.year).to_i
      )
    end
  end
end
