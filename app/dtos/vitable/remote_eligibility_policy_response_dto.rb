module Vitable
  RemoteEligibilityPolicyResponseDto = Data.define(
    :remote_policy_id,
    :remote_employer_id,
    :raw_payload
  ) do
    def self.from_hash(payload)
      attributes = payload.respond_to?(:to_h) ? payload.to_h.stringify_keys : {}
      data = resource_payload(attributes)
      employer = nested_payload(data, "employer")

      new(
        remote_policy_id: first_present(data["id"], data["policy_id"], data["eligibility_policy_id"], data["benefit_eligibility_policy_id"]),
        remote_employer_id: first_present(data["employer_id"], data["employer_external_id"], employer["id"], employer["employer_id"]),
        raw_payload: data
      )
    end

    def validate!(expected_employer_id:)
      raise ArgumentError, "Vitable eligibility policy response did not include a remote policy ID" if remote_policy_id.blank?
      raise ArgumentError, "Vitable eligibility policy response did not include a remote employer ID" if remote_employer_id.blank?
      if expected_employer_id.present? && remote_employer_id != expected_employer_id
        raise ArgumentError, "Vitable eligibility policy response returned remote employer ID #{remote_employer_id}, expected #{expected_employer_id}"
      end

      self
    end

    def to_snapshot_hash
      raw_payload.merge(
        "id" => remote_policy_id,
        "employer_id" => remote_employer_id
      ).compact
    end

    def self.resource_payload(attributes)
      %w[data eligibility_policy benefit_eligibility_policy policy resource object].reduce(attributes) do |payload, key|
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
