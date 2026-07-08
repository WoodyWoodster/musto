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
      attributes = payload.to_h.stringify_keys
      amount = attributes.fetch("deduction_amount_in_cents", nil).presence ||
        attributes.fetch("amount_cents", nil).presence ||
        attributes.fetch("employee_deduction_in_cents", nil).presence

      new(
        remote_id: attributes.fetch("id", nil).presence || attributes.fetch("deduction_id", nil).presence,
        benefit_name: attributes.fetch("benefit_name", nil).presence || attributes.fetch("name", nil).presence,
        category: attributes.fetch("deduction_category", nil).presence || attributes.fetch("category", nil).presence,
        amount_cents: amount.to_i,
        frequency: attributes.fetch("frequency", nil),
        period_start_on: parse_date(attributes.fetch("period_start_date", nil).presence || attributes.fetch("period_start_on", nil).presence),
        period_end_on: parse_date(attributes.fetch("period_end_date", nil).presence || attributes.fetch("period_end_on", nil).presence),
        tax_classification: attributes.fetch("tax_classification", nil),
        remote_status: attributes.fetch("status", nil),
        raw_payload: attributes
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

    private_class_method :parse_date
  end
end
