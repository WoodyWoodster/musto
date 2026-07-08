module Vitable
  RemoteDependentDto = Data.define(
    :remote_id,
    :remote_employee_id,
    :reference_id,
    :first_name,
    :last_name,
    :relationship,
    :date_of_birth,
    :enrollment_status,
    :eligibility_status,
    :raw_payload
  ) do
    def self.from_hash(payload)
      attributes = payload.respond_to?(:to_h) ? payload.to_h.stringify_keys : {}
      employee = nested_payload(attributes, "employee")

      new(
        remote_id: first_present(attributes["id"], attributes["dependent_id"]),
        remote_employee_id: first_present(attributes["employee_id"], attributes["subscriber_id"], employee["id"]),
        reference_id: first_present(attributes["reference_id"], attributes["external_reference_id"]),
        first_name: attributes["first_name"],
        last_name: attributes["last_name"],
        relationship: first_present(attributes["relationship"], attributes["relationship_type"], attributes["dependent_type"]),
        date_of_birth: date_from(first_present(attributes["date_of_birth"], attributes["dob"])),
        enrollment_status: enrollment_status_for(first_present(attributes["enrollment_status"], attributes["status"])),
        eligibility_status: eligibility_status_for(first_present(attributes["eligibility_status"], attributes["verification_status"], attributes["status"])),
        raw_payload: attributes
      )
    end

    def missing_required_fields(existing: nil)
      {
        "first_name" => first_name.presence || existing&.first_name,
        "last_name" => last_name.presence || existing&.last_name,
        "relationship" => relationship.presence || existing&.relationship
      }.filter_map { |field, value| field if value.blank? }
    end

    def identity_key
      return if [ first_name, last_name, relationship, date_of_birth ].any?(&:blank?)

      [
        first_name.to_s.downcase,
        last_name.to_s.downcase,
        relationship,
        date_of_birth
      ]
    end

    def metadata(source:, refreshed_at:)
      {
        "source" => source,
        "vitable_last_snapshot_source" => source,
        "vitable_last_refreshed_at" => refreshed_at,
        "vitable_remote_employee_id" => remote_employee_id,
        "vitable_remote_reference_id" => reference_id,
        "vitable_last_resource_snapshot" => raw_payload.slice(
          "id",
          "dependent_id",
          "employee_id",
          "first_name",
          "last_name",
          "relationship",
          "relationship_type",
          "dependent_type",
          "date_of_birth",
          "dob",
          "status",
          "enrollment_status",
          "eligibility_status",
          "verification_status"
        ).compact
      }.compact
    end

    def attributes(existing: nil, source:, refreshed_at:)
      {
        first_name: first_name.presence || existing&.first_name,
        last_name: last_name.presence || existing&.last_name,
        relationship: relationship.presence || existing&.relationship,
        date_of_birth: date_of_birth || existing&.date_of_birth,
        enrollment_status: enrollment_status.presence || existing&.enrollment_status || "pending",
        eligibility_status: eligibility_status.presence || existing&.eligibility_status || "needs_review",
        vitable_id: remote_id.presence || existing&.vitable_id,
        metadata: existing&.metadata.to_h.stringify_keys.merge(metadata(source:, refreshed_at:))
      }.compact
    end

    def self.nested_payload(attributes, key)
      value = attributes.fetch(key, {})
      value.respond_to?(:to_h) ? value.to_h.stringify_keys : {}
    end

    def self.date_from(value)
      return value if value.is_a?(Date)
      return if value.blank?

      Date.iso8601(value.to_s)
    rescue ArgumentError
      nil
    end

    def self.enrollment_status_for(value)
      case value.to_s.downcase
      when "active", "accepted", "eligible", "enrolled"
        "enrolled"
      when "canceled", "cancelled", "deleted", "declined", "inactive", "removed", "terminated", "waived"
        "waived"
      when "pending", "needs_review", "review_required"
        "pending"
      end
    end

    def self.eligibility_status_for(value)
      case value.to_s.downcase
      when "active", "accepted", "approved", "eligible", "enrolled", "verified"
        "eligible"
      when "denied", "ineligible", "rejected"
        "ineligible"
      end
    end

    def self.first_present(*values)
      values.compact_blank.first
    end

    private_class_method :nested_payload, :date_from, :enrollment_status_for, :eligibility_status_for, :first_present
  end
end
