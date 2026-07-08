module Vitable
  RemoteCensusSyncResponseDto = Data.define(
    :remote_employer_id,
    :accepted_at,
    :raw_payload
  ) do
    def self.from_hash(payload)
      attributes = payload.to_h.stringify_keys
      data = attributes.fetch("data", attributes)
      data = data.respond_to?(:to_h) ? data.to_h.stringify_keys : {}

      new(
        remote_employer_id: data.fetch("employer_id", nil),
        accepted_at: data.fetch("accepted_at", nil),
        raw_payload: data
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
  end
end
