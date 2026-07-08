module Vitable
  WidgetTokenRequestDto = Data.define(:bound_entity_type, :employer_id, :employee_id, :requested_by) do
    def self.employer_from_params(params)
      attributes = ApplicationDto.coerce_hash(params)

      new(
        bound_entity_type: "employer",
        employer_id: optional_id(attributes, "employer_id"),
        employee_id: nil,
        requested_by: attributes.fetch("requested_by", "widget_token_broker")
      )
    end

    def self.employee_from_params(params)
      attributes = ApplicationDto.coerce_hash(params)

      new(
        bound_entity_type: "employee",
        employer_id: optional_id(attributes, "employer_id"),
        employee_id: attributes.fetch("employee_id").to_i,
        requested_by: attributes.fetch("requested_by", "widget_token_broker")
      )
    end

    def self.optional_id(attributes, key)
      value = attributes.fetch(key, nil)
      value.present? ? value.to_i : nil
    end
  end
end
