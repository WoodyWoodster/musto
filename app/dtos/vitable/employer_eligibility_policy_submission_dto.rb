module Vitable
  EmployerEligibilityPolicySubmissionDto = Data.define(
    :status,
    :source,
    :remote_employer_id,
    :remote_policy_id,
    :endpoint,
    :retrieve_endpoint,
    :payload,
    :remote_response,
    :remote_snapshot,
    :submitted_at,
    :error_class,
    :error_message
  ) do
    ENDPOINT_TEMPLATE = EndpointCatalog::EMPLOYER_ELIGIBILITY_POLICIES_BY_EMPLOYER

    def self.submitted(remote_employer_id:, payload:, response:, retrieval_response:, submitted_at:)
      remote_response = serialize_response(response)
      remote_snapshot = serialize_response(retrieval_response)
      remote_policy_id = policy_id_from(remote_snapshot).presence || policy_id_from(remote_response)

      new(
        status: "remote_submitted",
        source: "remote_api",
        remote_employer_id:,
        remote_policy_id:,
        endpoint: endpoint_for(remote_employer_id),
        retrieve_endpoint: retrieve_endpoint_for(remote_policy_id),
        payload: payload.to_h.stringify_keys,
        remote_response:,
        remote_snapshot:,
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
        remote_policy_id: nil,
        endpoint: endpoint_for(remote_employer_id),
        retrieve_endpoint: nil,
        payload: payload.to_h.stringify_keys,
        remote_response: {},
        remote_snapshot: {},
        submitted_at:,
        error_class: error.class.name,
        error_message: PayloadRedactor.error_message(error)
      )
    end

    def self.skipped(remote_employer_id:, payload:, submitted_at:)
      new(
        status: "remote_current",
        source: "remote_api",
        remote_employer_id:,
        remote_policy_id: nil,
        endpoint: endpoint_for(remote_employer_id),
        retrieve_endpoint: nil,
        payload: payload.to_h.stringify_keys,
        remote_response: {},
        remote_snapshot: {},
        submitted_at:,
        error_class: nil,
        error_message: nil
      )
    end

    def self.from_hash(payload)
      attributes = payload.to_h.stringify_keys
      remote_policy_id = attributes.fetch("remote_policy_id", nil) || policy_id_from(attributes.fetch("remote_response", {}))

      new(
        status: attributes.fetch("status", "pending"),
        source: attributes.fetch("source", "local"),
        remote_employer_id: attributes.fetch("remote_employer_id", nil),
        remote_policy_id:,
        endpoint: attributes.fetch("endpoint", ENDPOINT_TEMPLATE),
        retrieve_endpoint: attributes.fetch("retrieve_endpoint", nil) || retrieve_endpoint_for(remote_policy_id),
        payload: attributes.fetch("payload", {}).to_h.stringify_keys,
        remote_response: attributes.fetch("remote_response", {}).to_h.stringify_keys,
        remote_snapshot: attributes.fetch("remote_snapshot", {}).to_h.stringify_keys,
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
        "remote_policy_id" => remote_policy_id,
        "endpoint" => endpoint,
        "retrieve_endpoint" => retrieve_endpoint,
        "payload" => payload,
        "remote_response" => remote_response,
        "remote_snapshot" => remote_snapshot,
        "submitted_at" => submitted_at&.iso8601,
        "error_class" => error_class,
        "error_message" => error_message
      }.compact
    end

    def self.endpoint_for(remote_employer_id)
      return ENDPOINT_TEMPLATE if remote_employer_id.blank?

      EndpointCatalog.path(:employer_eligibility_policies, id: remote_employer_id)
    end

    def self.retrieve_endpoint_for(remote_policy_id)
      return if remote_policy_id.blank?

      EndpointCatalog.path(:benefit_eligibility_policy, id: remote_policy_id)
    end

    def self.serialize_response(response)
      serialized =
        if response.blank?
          {}
        elsif response.respond_to?(:deep_to_h)
          response.deep_to_h
        elsif response.respond_to?(:to_h)
          response.to_h
        else
          { "value" => response.to_s }
        end

      PayloadRedactor.redact(serialized.deep_stringify_keys)
    end

    def self.parse_time(value)
      return value if value.respond_to?(:iso8601)
      return if value.blank?

      Time.iso8601(value.to_s)
    rescue ArgumentError
      nil
    end

    def self.policy_id_from(response_hash)
      RemoteEligibilityPolicyResponseDto.from_hash(response_hash).remote_policy_id
    end

    private_class_method :endpoint_for, :retrieve_endpoint_for, :serialize_response, :parse_time, :policy_id_from
  end
end
