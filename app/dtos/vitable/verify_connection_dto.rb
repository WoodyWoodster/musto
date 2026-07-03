module Vitable
  VerifyConnectionDto = Data.define(:connection_id) do
    def self.from_params(params)
      new(connection_id: ApplicationDto.id_from(params))
    end
  end
end
