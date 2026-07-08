module Vitable
  RemotePayrollDeductionDto = Data.define(
    :remote_id,
    :benefit_name,
    :category,
    :amount_cents,
    :frequency,
    :period_start_on,
    :period_end_on,
    :tax_classification,
    :remote_status,
    :raw_payload
  ) do
    def self.from_hash(payload)
      attributes = resource_payload(payload.respond_to?(:to_h) ? payload.to_h.stringify_keys : {})
      benefit = nested_payload(attributes, "benefit")
      plan = nested_payload(attributes, "plan")
      enrollment = nested_payload(attributes, "enrollment")
      enrollment_benefit = nested_payload(enrollment, "benefit")
      amount = first_present(
        attributes["deduction_amount_in_cents"],
        attributes["amount_cents"],
        attributes["employee_deduction_in_cents"],
        attributes["amount_in_cents"]
      )
      remote_id = first_present(attributes["id"], attributes["deduction_id"], attributes["payroll_deduction_id"])
      benefit_name = first_present(attributes["benefit_name"], attributes["name"], benefit["name"], plan["name"], enrollment_benefit["name"])
      category = first_present(attributes["deduction_category"], attributes["category"], benefit["category"], plan["category"], enrollment_benefit["category"])
      period_start = first_present(attributes["period_start_date"], attributes["period_start_on"], attributes["statement_period_start"], attributes["pay_period_start"])
      period_end = first_present(attributes["period_end_date"], attributes["period_end_on"], attributes["statement_period_end"], attributes["pay_period_end"])
      amount_cents = amount.to_i
      period_start_on = parse_date(period_start)
      period_end_on = parse_date(period_end)

      new(
        remote_id:,
        benefit_name:,
        category:,
        amount_cents:,
        frequency: first_present(attributes["frequency"], attributes["deduction_frequency"]),
        period_start_on:,
        period_end_on:,
        tax_classification: first_present(attributes["tax_classification"], attributes["tax_treatment"]),
        remote_status: first_present(attributes["status"], attributes["deduction_status"]),
        raw_payload: attributes.merge(
          "id" => remote_id,
          "deduction_amount_in_cents" => amount_cents,
          "benefit_name" => benefit_name,
          "deduction_category" => category,
          "period_start_date" => period_start_on&.iso8601,
          "period_end_date" => period_end_on&.iso8601
        ).compact
      )
    end

    def payroll_code
      base = benefit_name.presence || category.presence || remote_id.presence || "BENEFIT"
      normalized = base.to_s.upcase.gsub(/[^A-Z0-9]+/, "_").gsub(/\A_+|_+\z/, "").delete_prefix("VITABLE_").presence || "BENEFIT"
      "VITABLE_#{normalized}"
    end

    def active?
      remote_status.blank? || !remote_status.to_s.downcase.in?(%w[inactive canceled cancelled deleted])
    end

    def payroll_status
      normalized_status = remote_status.to_s.downcase
      return "waived" if normalized_status.in?(%w[waived declined])
      return "waiting_on_enrollment" if normalized_status.in?(%w[pending started granted])
      active? && amount_cents.positive? ? "ready" : "inactive"
    end

    def metadata
      {
        "source" => "vitable_employee_deduction",
        "remote_id" => remote_id,
        "benefit_name" => benefit_name,
        "category" => category,
        "frequency" => frequency,
        "period_start_on" => period_start_on&.iso8601,
        "period_end_on" => period_end_on&.iso8601,
        "tax_classification" => tax_classification,
        "remote_status" => remote_status,
        "raw_payload" => raw_payload
      }.compact
    end

    def self.parse_date(value)
      return value if value.is_a?(Date)
      return value.to_date if value.respond_to?(:to_date)
      return if value.blank?

      Date.iso8601(value.to_s)
    rescue ArgumentError
      nil
    end

    def self.resource_payload(attributes)
      %w[
        data
        payroll_deduction
        payrollDeduction
        employee_deduction
        deduction
        resource
        object
      ].reduce(attributes) do |payload, key|
        value = payload[key]
        !value.nil? && value.respond_to?(:to_h) ? value.to_h.stringify_keys : payload
      end
    end

    def self.nested_payload(attributes, key)
      value = attributes[key]
      value.respond_to?(:to_h) ? value.to_h.stringify_keys : {}
    end

    def self.first_present(*values)
      values.compact_blank.first
    end

    private_class_method :parse_date, :resource_payload, :nested_payload, :first_present
  end
end
