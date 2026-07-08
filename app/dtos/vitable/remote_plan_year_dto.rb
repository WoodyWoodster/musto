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
    RESOURCE_ENVELOPE_KEYS = %w[data resource object].freeze
    PLAN_YEAR_ENVELOPE_KEYS = %w[plan_year planYear benefit_year benefitYear].freeze
    EMPLOYER_CONTEXT_KEYS = %w[
      employer
      employer_id
      employerId
      employer_reference_id
      employerReferenceId
      company
      company_id
      companyId
      company_reference_id
      companyReferenceId
    ].freeze

    def self.from_event(event)
      from_hash(event.payload, fallback_id: event.resource_id)
    end

    def self.from_hash(payload, fallback_id: nil)
      data = normalized_payload(payload)
      employer = nested_payload(data, "employer")
      company = nested_payload(data, "company")
      remote_plan_year_id = first_present(
        data["id"],
        data["plan_year_id"],
        data["planYearId"],
        data["benefit_year_id"],
        data["benefitYearId"],
        fallback_id
      )

      new(
        remote_plan_year_id:,
        remote_employer_id: first_present(data["employer_id"], data["employerId"], data["company_id"], data["companyId"], employer["id"], company["id"]),
        employer_reference_id: employer_reference_id_for(data, employer, company),
        year: year_from(data),
        starts_on: date_from(
          data,
          "starts_on",
          "startsOn",
          "start_date",
          "startDate",
          "effective_on",
          "effectiveOn",
          "coverage_start",
          "coverageStart",
          "coverage_start_on",
          "coverageStartOn"
        ),
        ends_on: date_from(
          data,
          "ends_on",
          "endsOn",
          "end_date",
          "endDate",
          "expires_on",
          "expiresOn",
          "coverage_end",
          "coverageEnd",
          "coverage_end_on",
          "coverageEndOn"
        ),
        open_enrollment_starts_on: date_from(
          data,
          "open_enrollment_starts_on",
          "openEnrollmentStartsOn",
          "open_enrollment_start_on",
          "openEnrollmentStartOn",
          "open_enrollment_start_date",
          "openEnrollmentStartDate",
          "enrollment_starts_on",
          "enrollmentStartsOn",
          "enrollment_start_date",
          "enrollmentStartDate"
        ),
        open_enrollment_ends_on: date_from(
          data,
          "open_enrollment_ends_on",
          "openEnrollmentEndsOn",
          "open_enrollment_end_on",
          "openEnrollmentEndOn",
          "open_enrollment_end_date",
          "openEnrollmentEndDate",
          "enrollment_ends_on",
          "enrollmentEndsOn",
          "enrollment_end_date",
          "enrollmentEndDate"
        ),
        status: first_present(data["status"], data["state"], data["plan_year_status"], data["planYearStatus"]),
        raw_payload: data.merge("id" => remote_plan_year_id).compact
      )
    end

    def self.normalized_payload(payload)
      attributes = payload.respond_to?(:to_h) ? payload.to_h.stringify_keys : {}

      plan_year_payload(resource_payload(attributes))
    end

    def self.resource_payload(attributes)
      RESOURCE_ENVELOPE_KEYS.reduce(attributes) do |data, key|
        value = data.fetch(key, nil)
        value.present? && value.respond_to?(:to_h) ? value.to_h.stringify_keys : data
      end
    end

    def self.plan_year_payload(attributes)
      PLAN_YEAR_ENVELOPE_KEYS.reduce(attributes) do |data, key|
        value = data.fetch(key, nil)
        if value.present? && value.respond_to?(:to_h)
          merge_employer_context(value.to_h.stringify_keys, data)
        else
          data
        end
      end
    end

    def self.merge_employer_context(plan_year, parent)
      parent.slice(*EMPLOYER_CONTEXT_KEYS).merge(plan_year)
    end

    def self.nested_payload(attributes, key)
      value = attributes.fetch(key, {})
      value.respond_to?(:to_h) ? value.to_h.stringify_keys : {}
    end

    def self.employer_reference_id_for(attributes, employer, company)
      first_present(
        attributes["employer_reference_id"],
        attributes["employerReferenceId"],
        attributes["company_reference_id"],
        attributes["companyReferenceId"],
        employer["reference_id"],
        employer["referenceId"],
        employer["external_reference_id"],
        employer["externalReferenceId"],
        company["reference_id"],
        company["referenceId"],
        company["external_reference_id"],
        company["externalReferenceId"]
      )
    end

    def self.year_from(attributes)
      explicit_year = first_present(
        scalar_value(attributes["plan_year"]),
        scalar_value(attributes["planYear"]),
        attributes["year"],
        attributes["coverage_year"],
        attributes["coverageYear"],
        attributes["benefit_year"],
        attributes["benefitYear"]
      )
      return explicit_year.to_i if explicit_year.present?

      date_from(
        attributes,
        "starts_on",
        "startsOn",
        "start_date",
        "startDate",
        "effective_on",
        "effectiveOn",
        "coverage_start",
        "coverageStart",
        "coverage_start_on",
        "coverageStartOn"
      )&.year
    end

    def self.scalar_value(value)
      value.respond_to?(:to_h) ? nil : value
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
