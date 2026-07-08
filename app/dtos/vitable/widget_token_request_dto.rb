module Vitable
  WidgetTokenRequestDto = Data.define(:bound_entity_type, :employee_id, :requested_by) do
    def self.employer_from_params(params)
      attributes = ApplicationDto.coerce_hash(params)

      new(
        bound_entity_type: "employer",
        employee_id: nil,
        requested_by: attributes.fetch("requested_by", "widget_token_broker")
      )
    end

    def self.employee_from_params(params)
      attributes = ApplicationDto.coerce_hash(params)

      new(
        bound_entity_type: "employee",
        employee_id: attributes.fetch("employee_id").to_i,
        requested_by: attributes.fetch("requested_by", "widget_token_broker")
      )
    end
  end
end
