module YearEnd
  DeliverFormDto = Data.define(:form_id, :delivered_by, :tax_year) do
    def self.from_params(params)
      attributes = ApplicationDto.coerce_hash(params)

      new(
        form_id: attributes.fetch(:id) { attributes.fetch("id") }.to_i,
        delivered_by: attributes.fetch("delivered_by", "ops_console"),
        tax_year: attributes.fetch("tax_year", Date.current.year).to_i
      )
    end
  end
end
