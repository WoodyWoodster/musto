module Vitable
  RemoteEmployerResponseDto = Data.define(
    :remote_employer_id,
    :reference_id,
    :raw_payload
  ) do
    def self.from_hash(payload)
      attributes = payload.to_h.stringify_keys
      data = attributes.fetch("data", attributes)
      data = data.fetch("employer", data) if data.respond_to?(:fetch)
      data = data.respond_to?(:to_h) ? data.to_h.stringify_keys : {}

      new(
        remote_employer_id: data.fetch("id", nil),
        reference_id: data.fetch("reference_id", nil),
        raw_payload: data
      )
    end

    def validate_create!(expected_reference_id:)
      raise ArgumentError, "Vitable employer create response did not include a remote employer ID" if remote_employer_id.blank?
      if expected_reference_id.present? && reference_id.present? && reference_id != expected_reference_id
        raise ArgumentError, "Vitable employer create response returned reference_id #{reference_id}, expected #{expected_reference_id}"
      end

      self
    end
  end
end
