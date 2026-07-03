module PayrollCalendar
  CompleteStepDto = Data.define(:approval_step_id, :completed_by) do
    def self.from_params(params)
      attributes = ApplicationDto.coerce_hash(params)

      new(
        approval_step_id: ApplicationDto.id_from(params),
        completed_by: attributes.fetch("completed_by", "ops_console")
      )
    end
  end
end
