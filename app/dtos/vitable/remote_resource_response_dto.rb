module Vitable
  RemoteResourceResponseDto = Data.define(
    :resource_type,
    :resource_id,
    :attributes,
    :raw_payload
  ) do
    def self.from_response(response_hash, resource_type:, resource_id:)
      payload = response_payload(response_hash)
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
      supported_resource_types.include?(resource_type.to_s)
    end

    def self.resource_attributes(data, resource_type:)
      if data.is_a?(Array)
        if supported_resource_type?(resource_type)
          raise ArgumentError, "Vitable #{resource_type} fetch response returned a data array; expected a single resource object"
        end

        data = data.first
      end

      return {} unless data.respond_to?(:to_h)

      attributes = data.to_h.deep_stringify_keys
      resource_payload(attributes, resource_type:)
    end

    def self.response_payload(response_hash)
      return response_hash.to_h.deep_stringify_keys if response_hash.respond_to?(:to_h)

      {}
    end

    def self.resource_payload(attributes, resource_type:)
      envelope_keys_for(resource_type).each do |key|
        value = attributes.fetch(key, nil)
        return value.to_h.stringify_keys if !value.nil? && value.respond_to?(:to_h)
      end

      attributes
    end

    def self.envelope_keys_for(resource_type)
      resource_envelope_keys.fetch(resource_type.to_s, %w[resource object])
    end

    def self.supported_resource_types
      %w[
        employee
        enrollment
        employer
        group
        webhook_event
        eligibility_policy
        benefit_eligibility_policy
      ]
    end

    def self.resource_envelope_keys
      {
        "employee" => %w[employee resource object],
        "enrollment" => %w[enrollment resource object],
        "employer" => %w[employer resource object],
        "group" => %w[group resource object],
        "webhook_event" => %w[webhook_event webhookEvent event resource object],
        "eligibility_policy" => %w[eligibility_policy benefit_eligibility_policy policy resource object],
        "benefit_eligibility_policy" => %w[benefit_eligibility_policy eligibility_policy policy resource object]
      }
    end

    private_class_method :resource_attributes, :response_payload, :resource_payload, :envelope_keys_for, :supported_resource_types, :resource_envelope_keys
  end
end
