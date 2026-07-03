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

    def submit_census_sync(employer_id, employees)
      body = {
        employer_id:,
        employees: employees.map { |employee| census_employee_payload(employee) }
      }

      instrument("employer.census_sync", :post, "/v1/employers/#{employer_id}/census-sync", request_body: body) do
        client.employers.submit_census_sync(employer_id, employees: body.fetch(:employees))
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

    def instrument(operation, method, path, request_body: {})
      started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      response = yield
      log_request(operation:, method:, path:, request_body:, response:, duration_ms: duration_since(started_at))
      response
    rescue VitableConnect::Errors::APIStatusError => e
      log_request(operation:, method:, path:, request_body:, error: e, status_code: e.status, duration_ms: duration_since(started_at))
      raise
    rescue VitableConnect::Errors::APIError => e
      log_request(operation:, method:, path:, request_body:, error: e, duration_ms: duration_since(started_at))
      raise
    end

    def log_request(operation:, method:, path:, duration_ms:, request_body: {}, response: nil, error: nil, status_code: nil)
      @connection.api_request_logs.create!(
        operation:,
        method: method.to_s.upcase,
        path:,
        status_code: status_code || 200,
        duration_ms:,
        request_body:,
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

    def census_employee_payload(employee)
      attributes = employee.to_h.deep_symbolize_keys
      attributes[:date_of_birth] = Date.iso8601(attributes.fetch(:date_of_birth)) if attributes[:date_of_birth].is_a?(String)
      attributes[:start_date] = Date.iso8601(attributes.fetch(:start_date)) if attributes[:start_date].is_a?(String)
      attributes[:compensation_type] = attributes[:compensation_type].to_sym if attributes[:compensation_type].present?
      attributes[:employee_class] = attributes[:employee_class].to_sym if attributes[:employee_class].present?
      attributes[:address] = census_address_payload(attributes[:address]) if attributes[:address].present?
      attributes.compact
    end

    def census_address_payload(address)
      attributes = address.to_h.deep_symbolize_keys
      attributes[:state] = attributes[:state].to_sym if attributes[:state].present?
      attributes.compact
    end
  end
end
