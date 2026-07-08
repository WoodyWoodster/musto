module Vitable
  RemoteCollectionResponseDto = Data.define(
    :response_label,
    :records,
    :raw_payload
  ) do
    def self.from_response(response_hash, response_label:)
      payload = response_payload(response_hash)
      data = collection_data(payload)
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

    def self.response_payload(response_hash)
      return { "data" => response_hash } if response_hash.is_a?(Array)
      return response_hash.to_h.stringify_keys if response_hash.respond_to?(:to_h)

      {}
    end

    def self.collection_data(payload)
      collection = collection_from_keys(payload)
      return collection if collection.is_a?(Array)

      array_values = payload.values.select { |value| value.is_a?(Array) }
      array_values.one? ? array_values.first : nil
    end

    def self.collection_from_keys(payload)
      %w[data records items results resources collection].each do |key|
        value = payload.fetch(key, nil)
        return value if value.is_a?(Array)

        nested_collection = collection_from_keys(value.to_h.stringify_keys) if !value.nil? && value.respond_to?(:to_h) && value.to_h.present?
        return nested_collection if nested_collection.is_a?(Array)
      end

      nil
    end

    private_class_method :record_attributes, :response_payload, :collection_data, :collection_from_keys
  end
end
