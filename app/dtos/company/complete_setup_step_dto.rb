module Company
  CompleteSetupStepDto = Data.define(:step_key) do
    def self.from_params(params)
      attributes = ApplicationDto.coerce_hash(params)

      new(step_key: attributes.fetch("step_key", attributes[:step_key]).to_s)
    end
  end
end
