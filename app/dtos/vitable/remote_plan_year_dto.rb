module Vitable
  RemotePlanYearDto = Data.define(
    :remote_plan_year_id,
    :remote_employer_id,
    :employer_reference_id,
    :year,
    :starts_on,
    :ends_on,
    :open_enrollment_starts_on,
    :open_enrollment_ends_on,
    :status,
    :raw_payload
  ) do
    def self.from_event(event)
      from_hash(event.payload, fallback_id: event.resource_id)
    end

    def self.from_hash(payload, fallback_id: nil)
      attributes = payload.respond_to?(:to_h) ? payload.to_h.stringify_keys : {}
      data = resource_payload(attributes)
      employer = nested_payload(data, "employer")

      new(
        remote_plan_year_id: first_present(data["id"], data["plan_year_id"], fallback_id),
        remote_employer_id: first_present(data["employer_id"], data["company_id"], employer["id"]),
        employer_reference_id: first_present(data["employer_reference_id"], employer["reference_id"], employer["external_reference_id"]),
        year: year_from(data),
        starts_on: date_from(data, "starts_on", "start_date", "effective_on", "coverage_start", "coverage_start_on"),
        ends_on: date_from(data, "ends_on", "end_date", "expires_on", "coverage_end", "coverage_end_on"),
        open_enrollment_starts_on: date_from(data, "open_enrollment_starts_on", "open_enrollment_start_on", "open_enrollment_start_date", "enrollment_starts_on", "enrollment_start_date"),
        open_enrollment_ends_on: date_from(data, "open_enrollment_ends_on", "open_enrollment_end_on", "open_enrollment_end_date", "enrollment_ends_on", "enrollment_end_date"),
        status: first_present(data["status"], data["state"]),
        raw_payload: data.merge("id" => first_present(data["id"], data["plan_year_id"], fallback_id)).compact
      )
    end

    def self.resource_payload(attributes)
      %w[data resource object].lazy.filter_map do |key|
        value = attributes.fetch(key, nil)
        value.to_h.stringify_keys if !value.nil? && value.respond_to?(:to_h)
      end.first || attributes
    end

    def self.nested_payload(attributes, key)
      value = attributes.fetch(key, {})
      value.respond_to?(:to_h) ? value.to_h.stringify_keys : {}
    end

    def self.year_from(attributes)
      explicit_year = first_present(attributes["plan_year"], attributes["year"], attributes["coverage_year"])
      return explicit_year.to_i if explicit_year.present?

      date_from(attributes, "starts_on", "start_date", "effective_on", "coverage_start", "coverage_start_on")&.year
    end

    def self.date_from(attributes, *keys)
      value = first_present(*keys.map { |key| attributes[key] })
      return value if value.is_a?(Date)
      return if value.blank?

      Date.iso8601(value.to_s)
    rescue ArgumentError
      nil
    end

    def self.first_present(*values)
      values.compact_blank.first
    end

    def snapshot_hash
      raw_payload.merge(
        "id" => remote_plan_year_id,
        "employer_id" => remote_employer_id,
        "employer_reference_id" => employer_reference_id,
        "plan_year" => year,
        "starts_on" => starts_on&.iso8601,
        "ends_on" => ends_on&.iso8601,
        "open_enrollment_starts_on" => open_enrollment_starts_on&.iso8601,
        "open_enrollment_ends_on" => open_enrollment_ends_on&.iso8601,
        "status" => status
      ).compact
    end
  end
end
