module Vitable
  WebhookSimulatorDto = Data.define(:event_options, :resource_options, :default_event_name, :default_resource_type, :default_resource_id) do
    DEFAULT_OPTIONS = [
      WebhookSimulationEventOptionDto.new(
        label: "Enrollment accepted",
        event_name: "enrollment.accepted",
        resource_type: "enrollment",
        sample_resource_id: "enrl_sandbox_primary_care"
      ),
      WebhookSimulationEventOptionDto.new(
        label: "Enrollment terminated",
        event_name: "enrollment.terminated",
        resource_type: "enrollment",
        sample_resource_id: "enrl_sandbox_primary_care"
      ),
      WebhookSimulationEventOptionDto.new(
        label: "Enrollment elected",
        event_name: "enrollment.elected",
        resource_type: "enrollment",
        sample_resource_id: "enrl_sandbox_primary_care"
      ),
      WebhookSimulationEventOptionDto.new(
        label: "Enrollment granted",
        event_name: "enrollment.granted",
        resource_type: "enrollment",
        sample_resource_id: "enrl_sandbox_primary_care"
      ),
      WebhookSimulationEventOptionDto.new(
        label: "Enrollment waived",
        event_name: "enrollment.waived",
        resource_type: "enrollment",
        sample_resource_id: "enrl_sandbox_primary_care"
      ),
      WebhookSimulationEventOptionDto.new(
        label: "Enrollment started",
        event_name: "enrollment.started",
        resource_type: "enrollment",
        sample_resource_id: "enrl_sandbox_primary_care"
      ),
      WebhookSimulationEventOptionDto.new(
        label: "Employee eligibility granted",
        event_name: "employee.eligibility_granted",
        resource_type: "employee",
        sample_resource_id: "empl_sandbox_casey"
      ),
      WebhookSimulationEventOptionDto.new(
        label: "Employee eligibility terminated",
        event_name: "employee.eligibility_terminated",
        resource_type: "employee",
        sample_resource_id: "empl_sandbox_casey"
      ),
      WebhookSimulationEventOptionDto.new(
        label: "Employee deactivated",
        event_name: "employee.deactivated",
        resource_type: "employee",
        sample_resource_id: "empl_sandbox_casey"
      ),
      WebhookSimulationEventOptionDto.new(
        label: "Employee deduction created",
        event_name: "employee.deduction_created",
        resource_type: "employee",
        sample_resource_id: "empl_sandbox_casey"
      ),
      WebhookSimulationEventOptionDto.new(
        label: "Employer eligibility policy created",
        event_name: "employer.eligibility_policy_created",
        resource_type: "employer",
        sample_resource_id: "empr_sandbox_atlas"
      )
    ].freeze

    def self.default
      first_option = DEFAULT_OPTIONS.first

      new(
        event_options: DEFAULT_OPTIONS,
        resource_options: DEFAULT_OPTIONS.map(&:resource_type).uniq,
        default_event_name: first_option.event_name,
        default_resource_type: first_option.resource_type,
        default_resource_id: first_option.sample_resource_id
      )
    end
  end
end
