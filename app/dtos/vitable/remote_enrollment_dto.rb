module Vitable
  RemoteEnrollmentDto = Data.define(
    :remote_id,
    :remote_employee_id,
    :remote_plan_id,
    :benefit_name,
    :remote_benefit_category,
    :remote_product_code,
    :status,
    :local_status,
    :answered_at,
    :coverage_start_on,
    :coverage_end_on,
    :terminated_at,
    :employee_deduction_cents,
    :employer_contribution_cents,
    :raw_payload
  ) do
    def self.from_hash(payload)
      attributes = resource_payload(payload.respond_to?(:to_h) ? payload.to_h.stringify_keys : {})
      benefit = attributes.fetch("benefit", {}).to_h.stringify_keys
      plan = attributes.fetch("plan", {}).to_h.stringify_keys

      new(
        remote_id: attributes.fetch("id", nil).presence || attributes.fetch("enrollment_id", nil).presence,
        remote_employee_id: attributes.fetch("employee_id", nil).presence || attributes.fetch("member_id", nil).presence || attributes.dig("employee", "id").presence,
        remote_plan_id: attributes.fetch("plan_id", nil).presence || attributes.fetch("product_id", nil).presence || benefit.fetch("id", nil).presence || plan.fetch("id", nil).presence,
        benefit_name: attributes.fetch("benefit_name", nil).presence || benefit.fetch("name", nil).presence || plan.fetch("name", nil).presence || attributes.fetch("name", nil).presence,
        remote_benefit_category: attributes.fetch("benefit_category", nil).presence || benefit.fetch("category", nil).presence || plan.fetch("category", nil).presence,
        remote_product_code: attributes.fetch("product_code", nil).presence || benefit.fetch("product_code", nil).presence || plan.fetch("product_code", nil).presence,
        status: attributes.fetch("status", nil),
        local_status: local_status_for(attributes.fetch("status", nil)),
        answered_at: parse_time(attributes.fetch("answered_at", nil)),
        coverage_start_on: parse_date(attributes.fetch("coverage_start", nil).presence || attributes.fetch("coverage_start_date", nil).presence || attributes.fetch("effective_on", nil).presence),
        coverage_end_on: parse_date(attributes.fetch("coverage_end", nil).presence || attributes.fetch("coverage_end_date", nil).presence),
        terminated_at: parse_time(attributes.fetch("terminated_at", nil)),
        employee_deduction_cents: parse_cents(attributes.fetch("employee_deduction_in_cents", nil).presence || attributes.fetch("deduction_amount_in_cents", nil).presence || attributes.fetch("amount_cents", nil).presence),
        employer_contribution_cents: parse_cents(attributes.fetch("employer_contribution_in_cents", nil)),
        raw_payload: attributes
      )
    end

    def validate_identity!(response_label: "Vitable API snapshot enrollment")
      reference = remote_id.presence || "unknown enrollment"
      raise ArgumentError, "#{response_label} #{reference} did not include a remote enrollment ID" if remote_id.blank?
      raise ArgumentError, "#{response_label} #{reference} did not include a remote employee ID" if remote_employee_id.blank?
      raise ArgumentError, "#{response_label} #{reference} did not include a remote benefit ID" if remote_plan_id.blank?

      self
    end

    def accepted?
      local_status == "accepted"
    end

    def active_deduction?
      accepted? && employee_deduction_cents.to_i.positive?
    end

    def deduction_payload(enrollment)
      {
        "id" => raw_payload.fetch("deduction_id", nil).presence,
        "enrollment_id" => remote_id,
        "plan_id" => remote_plan_id,
        "benefit_name" => benefit_name.presence || enrollment.benefit_plan.name,
        "employee_deduction_in_cents" => employee_deduction_amount(enrollment),
        "frequency" => raw_payload.fetch("frequency", nil).presence,
        "period_start_date" => raw_payload.fetch("period_start_date", nil).presence,
        "period_end_date" => raw_payload.fetch("period_end_date", nil).presence,
        "tax_classification" => raw_payload.fetch("tax_classification", nil).presence,
        "status" => deduction_status
      }.compact
    end

    def metadata
      {
        "vitable_remote_status" => status,
        "vitable_remote_employee_id" => remote_employee_id,
        "vitable_remote_plan_id" => remote_plan_id,
        "vitable_remote_benefit_name" => benefit_name,
        "vitable_remote_benefit" => benefit_snapshot,
        "vitable_remote_answered_at" => answered_at&.iso8601,
        "vitable_remote_coverage_start" => coverage_start_on&.iso8601,
        "vitable_remote_coverage_end" => coverage_end_on&.iso8601,
        "vitable_remote_terminated_at" => terminated_at&.iso8601,
        "vitable_employee_deduction_cents" => employee_deduction_cents,
        "vitable_employer_contribution_cents" => employer_contribution_cents,
        "vitable_last_resource_snapshot" => raw_payload.slice("id", "enrollment_id", "status", "employee_id", "member_id", "plan_id", "product_id", "benefit", "plan", "coverage_start", "coverage_end", "employee_deduction_in_cents", "employer_contribution_in_cents")
      }.compact
    end

    def benefit_snapshot
      {
        "id" => remote_plan_id,
        "name" => benefit_name,
        "category" => remote_benefit_category,
        "product_code" => remote_product_code
      }.compact
    end

    def self.local_status_for(remote_status)
      normalized = remote_status.to_s.downcase
      return "accepted" if normalized.in?(%w[accepted elected enrolled active])
      return "pending" if normalized.in?(%w[pending started granted])
      return "waived" if normalized.in?(%w[waived declined])
      return "inactive" if normalized.in?(%w[inactive terminated canceled cancelled])

      nil
    end

    def self.resource_payload(attributes)
      %w[data enrollment resource object].reduce(attributes) do |payload, key|
        value = payload.fetch(key, nil)
        !value.nil? && value.respond_to?(:to_h) ? value.to_h.stringify_keys : payload
      end
    end

    def self.parse_cents(value)
      return if value.blank?

      value.to_i
    end

    def self.parse_date(value)
      return value if value.is_a?(Date)
      return value.to_date if value.respond_to?(:to_date)
      return if value.blank?

      Date.iso8601(value.to_s)
    rescue ArgumentError
      nil
    end

    def self.parse_time(value)
      return value if value.respond_to?(:iso8601)
      return if value.blank?

      Time.iso8601(value.to_s)
    rescue ArgumentError
      nil
    end

    def employee_deduction_amount(enrollment)
      return 0 unless accepted?
      return employee_deduction_cents if employee_deduction_cents.present?

      enrollment.benefit_plan.monthly_premium_cents
    end

    def deduction_status
      return "active" if accepted?
      return "waived" if local_status == "waived"
      return "pending" if local_status == "pending"

      "inactive"
    end

    private_class_method :local_status_for, :resource_payload, :parse_cents, :parse_date, :parse_time
  end
end
