module Onboarding
  CompleteTaskDto = Data.define(:task_id) do
    def self.from_params(params)
      new(task_id: ApplicationDto.id_from(params))
    end
  end
end
