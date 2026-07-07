module Vitable
  CensusSyncSubmissionDto = Data.define(
    :batch_id,
    :status,
    :accepted_at,
    :submitted_at,
    :remote_employer_id,
    :ready_count,
    :employee_reference_ids
  ) do
    def self.from_hash(payload)
      attributes = payload.to_h.stringify_keys

      new(
        batch_id: attributes.fetch("batch_id", nil),
        status: attributes.fetch("status", "pending"),
        accepted_at: parse_time(attributes.fetch("accepted_at", nil)),
        submitted_at: parse_time(attributes.fetch("submitted_at", nil)),
        remote_employer_id: attributes.fetch("remote_employer_id", nil),
        ready_count: attributes.fetch("ready_count", 0),
        employee_reference_ids: attributes.fetch("employee_reference_ids", [])
      )
    end

    def self.parse_time(value)
      return value if value.respond_to?(:iso8601)
      return if value.blank?

      Time.iso8601(value.to_s)
    end
  end
end
