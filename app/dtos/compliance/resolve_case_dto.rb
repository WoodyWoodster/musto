module Compliance
  ResolveCaseDto = Data.define(:compliance_case_id) do
    def self.from_params(params)
      new(compliance_case_id: ApplicationDto.id_from(params))
    end
  end
end
