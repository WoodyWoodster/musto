module Taxes
  GenerateAgencyRegistrationPacketDto = Data.define(:requested_by) do
    def self.from_params(params)
      attributes = ApplicationDto.coerce_hash(params)

      new(requested_by: attributes.fetch("requested_by", "ops_console"))
    end
  end
end
