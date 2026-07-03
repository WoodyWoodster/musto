module Onboarding
  CompleteTaskDto = Data.define(:task_id, :return_to) do
    def self.from_params(params)
      attributes = ApplicationDto.coerce_hash(params)

      new(
        task_id: ApplicationDto.id_from(params),
        return_to: attributes["return_to"] || attributes[:return_to]
      )
    end
  end
end
