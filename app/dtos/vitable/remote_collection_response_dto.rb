module Vitable
  RemoteCollectionResponseDto = Data.define(
    :response_label,
    :records,
    :raw_payload
  ) do
    def self.from_response(response_hash, response_label:)
      payload = response_hash.to_h.stringify_keys
      data = payload.fetch("data", nil)
      raise ArgumentError, "#{response_label} did not include a data array" unless data.is_a?(Array)

      new(
        response_label:,
        records: data.each_with_index.map { |entry, index| record_attributes(entry, index:, response_label:) },
        raw_payload: payload
      )
    end

    def self.record_attributes(entry, index:, response_label:)
      raise ArgumentError, "#{response_label} item #{index + 1} was not a resource object" unless entry.respond_to?(:to_h)

      entry.to_h.stringify_keys
    end

    private_class_method :record_attributes
  end
end
