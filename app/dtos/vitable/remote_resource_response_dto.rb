module Vitable
  RemoteResourceResponseDto = Data.define(
    :resource_type,
    :resource_id,
    :attributes,
    :raw_payload
  ) do
    SUPPORTED_RESOURCE_TYPES = %w[
      employee
      enrollment
      employer
      group
      webhook_event
      eligibility_policy
      benefit_eligibility_policy
    ].freeze

    def self.from_response(response_hash, resource_type:, resource_id:)
      payload = response_hash.to_h.stringify_keys
      normalized_resource_type = resource_type.to_s
      data = payload.fetch("data", payload)

      new(
        resource_type: normalized_resource_type,
        resource_id:,
        attributes: resource_attributes(data, resource_type: normalized_resource_type),
        raw_payload: payload
      )
    end

    def validate!
      if supported_resource_type? && attributes.blank?
        raise ArgumentError, "Vitable #{resource_type} fetch response did not include resource attributes"
      end

      self
    end

    def supported_resource_type?
      self.class.supported_resource_type?(resource_type)
    end

    def self.supported_resource_type?(resource_type)
      SUPPORTED_RESOURCE_TYPES.include?(resource_type.to_s)
    end

    def self.resource_attributes(data, resource_type:)
      if data.is_a?(Array)
        if supported_resource_type?(resource_type)
          raise ArgumentError, "Vitable #{resource_type} fetch response returned a data array; expected a single resource object"
        end

        data = data.first
      end

      return {} unless data.respond_to?(:to_h)

      data.to_h.stringify_keys
    end

    private_class_method :resource_attributes
  end
end
