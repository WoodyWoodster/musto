module Vitable
  RemoteEmployerSettingsResponseDto = Data.define(
    :pay_frequency,
    :raw_payload
  ) do
    def self.from_hash(payload)
      attributes = payload.to_h.stringify_keys
      data = attributes.fetch("data", attributes)
      data = data.respond_to?(:to_h) ? data.to_h.stringify_keys : {}

      new(
        pay_frequency: data.fetch("pay_frequency", nil)&.to_s,
        raw_payload: data
      )
    end

    def validate!(expected_pay_frequency:)
      raise ArgumentError, "Vitable employer settings response did not include pay_frequency" if pay_frequency.blank?
      if expected_pay_frequency.present? && pay_frequency != expected_pay_frequency
        raise ArgumentError, "Vitable employer settings response returned pay_frequency #{pay_frequency}, expected #{expected_pay_frequency}"
      end

      self
    end
  end
end
