module Vitable
  RemoteEmployerSettingsResponseDto = Data.define(
    :pay_frequency,
    :raw_payload
  ) do
    def self.from_hash(payload)
      attributes = payload.respond_to?(:to_h) ? payload.to_h.stringify_keys : {}
      data = resource_payload(attributes)

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

    def to_metadata
      raw_payload.slice("pay_frequency").compact
    end

    def self.resource_payload(attributes)
      %w[data settings employer_settings resource object].reduce(attributes) do |payload, key|
        value = payload[key]
        !value.nil? && value.respond_to?(:to_h) ? value.to_h.stringify_keys : payload
      end
    end

    private_class_method :resource_payload
  end
end
