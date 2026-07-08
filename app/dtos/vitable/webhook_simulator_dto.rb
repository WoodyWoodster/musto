module Vitable
  WebhookSimulatorDto = Data.define(:event_options, :resource_options, :default_event_name, :default_resource_type, :default_resource_id) do
    EVENT_DEFINITIONS = [
      { label: "Enrollment accepted", event_name: "enrollment.accepted", resource_type: "enrollment" },
      { label: "Enrollment terminated", event_name: "enrollment.terminated", resource_type: "enrollment" },
      { label: "Enrollment elected", event_name: "enrollment.elected", resource_type: "enrollment" },
      { label: "Enrollment granted", event_name: "enrollment.granted", resource_type: "enrollment" },
      { label: "Enrollment waived", event_name: "enrollment.waived", resource_type: "enrollment" },
      { label: "Enrollment started", event_name: "enrollment.started", resource_type: "enrollment" },
      { label: "Employee eligibility granted", event_name: "employee.eligibility_granted", resource_type: "employee" },
      { label: "Employee eligibility terminated", event_name: "employee.eligibility_terminated", resource_type: "employee" },
      { label: "Employee deactivated", event_name: "employee.deactivated", resource_type: "employee" },
      { label: "Employee deduction created", event_name: "employee.deduction_created", resource_type: "employee" },
      { label: "Employer eligibility policy created", event_name: "employer.eligibility_policy_created", resource_type: "employer" },
      { label: "Group updated", event_name: "group.updated", resource_type: "group" }
    ].freeze

    def self.default
      from_resource_ids({})
    end

    def self.from_resource_ids(resource_ids)
      resources = resource_ids.to_h.stringify_keys
      options = EVENT_DEFINITIONS.map do |definition|
        WebhookSimulationEventOptionDto.new(
          label: definition.fetch(:label),
          event_name: definition.fetch(:event_name),
          resource_type: definition.fetch(:resource_type),
          sample_resource_id: resources.fetch(definition.fetch(:resource_type), nil).to_s
        )
      end
      first_option = options.find { |option| option.sample_resource_id.present? } || options.first

      new(
        event_options: options,
        resource_options: options.map(&:resource_type).uniq,
        default_event_name: first_option.event_name,
        default_resource_type: first_option.resource_type,
        default_resource_id: first_option.sample_resource_id
      )
    end
  end
end
