module Vitable
  RemoteCensusSyncResponseDto = Data.define(
    :remote_employer_id,
    :accepted_at,
    :raw_payload
  ) do
    def self.from_hash(payload)
      attributes = payload.respond_to?(:to_h) ? payload.to_h.stringify_keys : {}
      data = resource_payload(attributes)
      employer = nested_payload(data, "employer")
      remote_employer_id = first_present(data["employer_id"], data["employer_external_id"], employer["id"], employer["employer_id"])
      accepted_at = first_present(data["accepted_at"], data["submitted_at"], data["created_at"])

      new(
        remote_employer_id:,
        accepted_at:,
        raw_payload: data.merge(
          "employer_id" => remote_employer_id,
          "accepted_at" => accepted_at
        ).compact
      )
    end

    def validate!(expected_employer_id:)
      raise ArgumentError, "Vitable census sync response did not include accepted_at" if accepted_at.blank?
      raise ArgumentError, "Vitable census sync response did not include a remote employer ID" if remote_employer_id.blank?
      if expected_employer_id.present? && remote_employer_id != expected_employer_id
        raise ArgumentError, "Vitable census sync response returned remote employer ID #{remote_employer_id}, expected #{expected_employer_id}"
      end

      self
    end

    def self.resource_payload(attributes)
      %w[
        data
        census_sync
        census_sync_request
        census
        submission
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

    private_class_method :resource_payload, :nested_payload, :first_present
  end
end
