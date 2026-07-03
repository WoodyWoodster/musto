module Vitable
  WebhookSimulatorDto = Data.define(:event_options, :resource_options, :default_event_name, :default_resource_type, :default_resource_id) do
    DEFAULT_OPTIONS = [
      WebhookSimulationEventOptionDto.new(
        label: "Employee created",
        event_name: "employee.created",
        resource_type: "employee",
        sample_resource_id: "empl_sandbox_new_hire"
      ),
      WebhookSimulationEventOptionDto.new(
        label: "Enrollment accepted",
        event_name: "enrollment.accepted",
        resource_type: "enrollment",
        sample_resource_id: "enrl_sandbox_primary_care"
      ),
      WebhookSimulationEventOptionDto.new(
        label: "Benefit plan updated",
        event_name: "benefit_plan.updated",
        resource_type: "benefit_plan",
        sample_resource_id: "bpln_sandbox_direct_primary_care"
      ),
      WebhookSimulationEventOptionDto.new(
        label: "Payroll deduction generated",
        event_name: "payroll_deduction.generated",
        resource_type: "payroll_deduction",
        sample_resource_id: "pded_sandbox_benefits"
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
