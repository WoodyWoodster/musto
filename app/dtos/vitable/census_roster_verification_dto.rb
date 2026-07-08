module Vitable
  CensusRosterVerificationDto = Data.define(
    :status,
    :checked_at,
    :submitted_count,
    :remote_employee_count,
    :matched_submitted_count,
    :missing_submitted_count,
    :unmatched_remote_count,
    :missing_reference_ids,
    :reason
  ) do
    def self.from_hash(payload)
      attributes = payload.to_h.stringify_keys

      new(
        status: attributes.fetch("status", "pending"),
        checked_at: parse_time(attributes.fetch("checked_at", nil)),
        submitted_count: attributes.fetch("submitted_count", 0),
        remote_employee_count: attributes.fetch("remote_employee_count", 0),
        matched_submitted_count: attributes.fetch("matched_submitted_count", 0),
        missing_submitted_count: attributes.fetch("missing_submitted_count", 0),
        unmatched_remote_count: attributes.fetch("unmatched_remote_count", 0),
        missing_reference_ids: attributes.fetch("missing_reference_ids", []),
        reason: attributes.fetch("reason", "Refresh the remote roster after census submission.")
      )
    end

    def present?
      checked_at.present?
    end

    def self.parse_time(value)
      return value if value.respond_to?(:iso8601)
      return if value.blank?

      Time.iso8601(value.to_s)
    end

    private_class_method :parse_time
  end
end
