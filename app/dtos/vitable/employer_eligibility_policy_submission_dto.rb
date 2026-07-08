module Vitable
  EmployerEligibilityPolicySubmissionDto = Data.define(
    :status,
    :source,
    :remote_employer_id,
    :endpoint,
    :payload,
    :remote_response,
    :submitted_at,
    :error_class,
    :error_message
  ) do
    ENDPOINT_TEMPLATE = "/v1/employers/:employer_id/benefit-eligibility-policies"

    def self.submitted(remote_employer_id:, payload:, response:, submitted_at:)
      new(
        status: "remote_submitted",
        source: "remote_api",
        remote_employer_id:,
        endpoint: endpoint_for(remote_employer_id),
        payload: payload.to_h.stringify_keys,
        remote_response: serialize_response(response),
        submitted_at:,
        error_class: nil,
        error_message: nil
      )
    end

    def self.existing(remote_employer_id:, payload:, error:, submitted_at:)
      new(
        status: "remote_existing",
        source: "remote_existing",
        remote_employer_id:,
        endpoint: endpoint_for(remote_employer_id),
        payload: payload.to_h.stringify_keys,
        remote_response: {},
        submitted_at:,
        error_class: error.class.name,
        error_message: error.message
      )
    end

    def self.skipped(remote_employer_id:, payload:, submitted_at:)
      new(
        status: "remote_current",
        source: "remote_api",
        remote_employer_id:,
        endpoint: endpoint_for(remote_employer_id),
        payload: payload.to_h.stringify_keys,
        remote_response: {},
        submitted_at:,
        error_class: nil,
        error_message: nil
      )
    end

    def self.from_hash(payload)
      attributes = payload.to_h.stringify_keys

      new(
        status: attributes.fetch("status", "pending"),
        source: attributes.fetch("source", "local"),
        remote_employer_id: attributes.fetch("remote_employer_id", nil),
        endpoint: attributes.fetch("endpoint", ENDPOINT_TEMPLATE),
        payload: attributes.fetch("payload", {}).to_h.stringify_keys,
        remote_response: attributes.fetch("remote_response", {}).to_h.stringify_keys,
        submitted_at: parse_time(attributes.fetch("submitted_at", nil)),
        error_class: attributes.fetch("error_class", nil),
        error_message: attributes.fetch("error_message", nil)
      )
    end

    def to_metadata
      {
        "status" => status,
        "source" => source,
        "remote_employer_id" => remote_employer_id,
        "endpoint" => endpoint,
        "payload" => payload,
        "remote_response" => remote_response,
        "submitted_at" => submitted_at&.iso8601,
        "error_class" => error_class,
        "error_message" => error_message
      }.compact
    end

    def self.endpoint_for(remote_employer_id)
      return ENDPOINT_TEMPLATE if remote_employer_id.blank?

      "/v1/employers/#{remote_employer_id}/benefit-eligibility-policies"
    end

    def self.serialize_response(response)
      return {} if response.blank?
      return response.deep_to_h.deep_stringify_keys if response.respond_to?(:deep_to_h)
      return response.to_h.deep_stringify_keys if response.respond_to?(:to_h)

      { "value" => response.to_s }
    end

    def self.parse_time(value)
      return value if value.respond_to?(:iso8601)
      return if value.blank?

      Time.iso8601(value.to_s)
    rescue ArgumentError
      nil
    end

    private_class_method :endpoint_for, :serialize_response, :parse_time
  end
end
