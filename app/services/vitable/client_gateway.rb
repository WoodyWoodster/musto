require "vitable_connect"

module Vitable
  class ClientGateway
    def initialize(connection)
      @connection = connection
    end

    def issue_access_token
      instrument("auth.issue_access_token", :post, "/auth/token") do
        client.auth.issue_access_token(grant_type: "client_credentials")
      end
    end

    def fetch_resource(resource_type, resource_id)
      path = "/#{resource_type.to_s.pluralize}/#{resource_id}"

      instrument("resource.fetch", :get, path) do
        client.request(method: :get, path:)
      end
    end

    private

    def client
      @client ||= VitableConnect::Client.new(
        api_key: @connection.api_key,
        environment: @connection.environment,
        max_retries: 2,
        timeout: 15
      )
    end

    def instrument(operation, method, path)
      started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      response = yield
      log_request(operation:, method:, path:, response:, duration_ms: duration_since(started_at))
      response
    rescue VitableConnect::Errors::APIStatusError => e
      log_request(operation:, method:, path:, error: e, status_code: e.status, duration_ms: duration_since(started_at))
      raise
    rescue VitableConnect::Errors::APIError => e
      log_request(operation:, method:, path:, error: e, duration_ms: duration_since(started_at))
      raise
    end

    def log_request(operation:, method:, path:, duration_ms:, response: nil, error: nil, status_code: nil)
      @connection.api_request_logs.create!(
        operation:,
        method: method.to_s.upcase,
        path:,
        status_code: status_code || 200,
        duration_ms:,
        response_body: serialize_response(response),
        error_class: error&.class&.name,
        error_message: error&.message
      )
    end

    def duration_since(started_at)
      ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at) * 1000).round
    end

    def serialize_response(response)
      return {} if response.blank?
      return response.deep_to_h if response.respond_to?(:deep_to_h)
      return response.to_h if response.respond_to?(:to_h)

      { value: response.to_s }
    end
  end
end
