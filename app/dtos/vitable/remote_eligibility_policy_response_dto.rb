module Vitable
  RemoteEligibilityPolicyResponseDto = Data.define(
    :remote_policy_id,
    :remote_employer_id,
    :raw_payload
  ) do
    def self.from_hash(payload)
      attributes = payload.to_h.stringify_keys
      data = attributes.fetch("data", attributes)
      data = data.fetch("eligibility_policy", data) if data.respond_to?(:fetch)
      data = data.fetch("benefit_eligibility_policy", data) if data.respond_to?(:fetch)
      data = data.respond_to?(:to_h) ? data.to_h.stringify_keys : {}

      new(
        remote_policy_id: data.fetch("id", nil) || data.fetch("policy_id", nil),
        remote_employer_id: data.fetch("employer_id", nil),
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
  end
end
