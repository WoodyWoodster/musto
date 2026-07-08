require "vitable_connect"

module Vitable
  class ClientGateway
    def initialize(connection)
      @connection = connection
    end

    def issue_access_token
      body = { grant_type: "client_credentials" }

      instrument("auth.issue_access_token", :post, "/v1/auth/access-tokens", request_body: body) do
        client.auth.issue_access_token(grant_type: :client_credentials)
      end
    end

    def issue_employee_access_token(employee_id)
      body = {
        grant_type: "client_credentials",
        bound_entity: { type: "employee", id: employee_id }
      }

      instrument("auth.issue_employee_access_token", :post, "/v1/auth/access-tokens", request_body: body) do
        client.auth.issue_access_token(
          grant_type: :client_credentials,
          bound_entity: { type: :employee, id: employee_id }
        )
      end
    end

    def fetch_resource(resource_type, resource_id)
      case resource_type.to_s
      when "employee"
        retrieve_employee(resource_id)
      when "employer"
        retrieve_employer(resource_id)
      when "enrollment"
        retrieve_enrollment(resource_id)
      when "webhook_event"
        retrieve_webhook_event(resource_id)
      when "group"
        retrieve_group(resource_id)
      else
        raise ArgumentError, "Vitable SDK does not expose a retrieve endpoint for #{resource_type}"
      end
    end

    def retrieve_employee(employee_id)
      instrument("resource.fetch", :get, "/v1/employees/#{employee_id}") do
        client.employees.retrieve(employee_id)
      end
    end

    def retrieve_employer(employer_id)
      instrument("resource.fetch", :get, "/v1/employers/#{employer_id}") do
        client.employers.retrieve(employer_id)
      end
    end

    def retrieve_enrollment(enrollment_id)
      instrument("resource.fetch", :get, "/v1/enrollments/#{enrollment_id}") do
        client.enrollments.retrieve(enrollment_id)
      end
    end

    def list_employers(limit: 100)
      query = { limit: }

      instrument("employer.list", :get, "/v1/employers", request_body: query) do
        client.employers.list(query)
      end
    end

    def list_all_employers(limit: 100)
      query = { limit: }

      instrument("employer.list", :get, "/v1/employers", request_body: query) do
        page_response(client.employers.list(query))
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

    def list_employer_employees(employer_id, limit: 100)
      query = { limit: }

      instrument("employer.list_employees", :get, "/v1/employers/#{employer_id}/employees", request_body: query) do
        client.employers.list_employees(employer_id, query)
      end
    end

    def list_all_employer_employees(employer_id, limit: 100)
      query = { limit: }

      instrument("employer.list_employees", :get, "/v1/employers/#{employer_id}/employees", request_body: query) do
        page_response(client.employers.list_employees(employer_id, query))
      end
    end

    def list_employee_enrollments(employee_id, limit: 100)
      query = { limit: }

      instrument("employee.list_enrollments", :get, "/v1/employees/#{employee_id}/enrollments", request_body: query) do
        client.employees.list_enrollments(employee_id, query)
      end
    end

    def list_all_employee_enrollments(employee_id, limit: 100)
      query = { limit: }

      instrument("employee.list_enrollments", :get, "/v1/employees/#{employee_id}/enrollments", request_body: query) do
        page_response(client.employees.list_enrollments(employee_id, query))
      end
    end

    def list_plans(limit: 100)
      query = { limit: }

      instrument("plan.list", :get, "/v1/plans", request_body: query) do
        client.plans.list(query)
      end
    end

    def list_all_plans(limit: 100)
      query = { limit: }

      instrument("plan.list", :get, "/v1/plans", request_body: query) do
        page_response(client.plans.list(query))
      end
    end

    def list_webhook_events(limit: 20)
      query = { limit: }

      instrument("webhook_event.list", :get, "/v1/webhook-events", request_body: query) do
        client.webhook_events.list(query)
      end
    end

    def list_all_webhook_events(limit: 100)
      query = { limit: }

      instrument("webhook_event.list", :get, "/v1/webhook-events", request_body: query) do
        page_response(client.webhook_events.list(query))
      end
    end

    def retrieve_webhook_event(event_id)
      instrument("webhook_event.retrieve", :get, "/v1/webhook-events/#{event_id}") do
        client.webhook_events.retrieve(event_id)
      end
    end

    def list_webhook_event_deliveries(event_id)
      instrument("webhook_event.list_deliveries", :get, "/v1/webhook-events/#{event_id}/deliveries") do
        client.webhook_events.list_deliveries(event_id)
      end
    end

    def list_groups(limit: 100)
      query = { limit: }

      instrument("group.list", :get, "/v1/groups", request_body: query) do
        client.groups.list(query)
      end
    end

    def list_all_groups(limit: 100)
      query = { limit: }

      instrument("group.list", :get, "/v1/groups", request_body: query) do
        page_response(client.groups.list(query))
      end
    end

    def create_employer(payload)
      body = employer_create_payload(payload)

      instrument("employer.create", :post, "/v1/employers", request_body: body) do
        client.employers.create(body)
      end
    end

    def update_employer_settings(employer_id, pay_frequency)
      body = { pay_frequency: pay_frequency_value(pay_frequency) }

      instrument("employer.update_settings", :put, "/v1/employers/#{employer_id}/settings", request_body: body) do
        client.employers.update_settings(employer_id, body)
      end
    end

    def create_eligibility_policy(employer_id, payload)
      body = eligibility_policy_payload(payload)
      path = "/v1/employers/#{employer_id}/benefit-eligibility-policies"

      instrument("employer.eligibility_policy.create", :post, path, request_body: body) do
        client.request(
          method: :post,
          path: "v1/employers/#{employer_id}/benefit-eligibility-policies",
          body:,
          model: VitableConnect::Internal::Type::Unknown
        )
      end
    end

    def create_group(payload)
      body = group_payload(payload)

      instrument("group.create", :post, "/v1/groups", request_body: body) do
        client.groups.create(body)
      end
    end

    def update_group(group_id, payload)
      body = group_payload(payload)

      instrument("group.update", :patch, "/v1/groups/#{group_id}", request_body: body) do
        client.groups.update(group_id, body)
      end
    end

    def retrieve_group(group_id)
      instrument("group.retrieve", :get, "/v1/groups/#{group_id}") do
        client.groups.retrieve(group_id)
      end
    end

    def submit_group_member_sync(group_id, members)
      body = {
        group_id:,
        members: members.map { |member| group_member_payload(member) }
      }

      instrument("group.member_sync.submit", :post, "/v1/groups/#{group_id}/members/sync", request_body: body) do
        client.groups.members.sync.submit(group_id, members: body.fetch(:members))
      end
    end

    def retrieve_group_member_sync(group_id, request_id)
      instrument("group.member_sync.retrieve", :get, "/v1/groups/#{group_id}/members/sync/#{request_id}") do
        client.groups.members.sync.retrieve(request_id, group_id:)
      end
    end

    private

    def client
      @client ||= VitableConnect::Client.new(
        api_key: @connection.api_key,
        environment: @connection.environment,
        base_url: @connection.effective_api_base_url,
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
      serialized = if response.blank?
        {}
      elsif response.respond_to?(:deep_to_h)
        response.deep_to_h
      elsif response.respond_to?(:to_h)
        response.to_h
      else
        { value: response.to_s }
      end

      redact_token_values(serialized.deep_stringify_keys)
    end

    def page_response(page)
      { data: collect_page_data(page) }
    end

    def collect_page_data(page)
      return [] if page.blank?

      if page.respond_to?(:auto_paging_each)
        items = []
        page.auto_paging_each { |item| items << serialize_response(item) }
        items
      else
        Array(page_data(page)).map { |item| serialize_response(item) }
      end
    end

    def page_data(page)
      return page.data if page.respond_to?(:data)

      serialized = page.respond_to?(:deep_to_h) ? page.deep_to_h : page.to_h
      serialized.fetch(:data, serialized.fetch("data", []))
    end

    def redact_token_values(value)
      case value
      when Hash
        value.to_h do |key, entry|
          [ key, key == "access_token" ? "[FILTERED]" : redact_token_values(entry) ]
        end
      when Array
        value.map { |entry| redact_token_values(entry) }
      else
        value
      end
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

    def employer_create_payload(payload)
      attributes = payload.to_h.deep_symbolize_keys
      attributes[:address] = attributes[:address].to_h.deep_symbolize_keys.compact if attributes[:address].present?
      attributes.compact
    end

    def group_payload(payload)
      payload.to_h.deep_symbolize_keys.slice(:external_reference_id, :name).compact
    end

    def eligibility_policy_payload(payload)
      payload.to_h.deep_symbolize_keys.slice(:classification, :waiting_period).compact
    end

    def group_member_payload(member)
      attributes = member.to_h.deep_symbolize_keys
      attributes[:date_of_birth] = Date.iso8601(attributes.fetch(:date_of_birth)) if attributes[:date_of_birth].is_a?(String)
      attributes[:address] = attributes.fetch(:address, {}).to_h.deep_symbolize_keys.compact
      attributes.slice(
        :reference_id,
        :first_name,
        :last_name,
        :email,
        :phone,
        :date_of_birth,
        :plan_id,
        :address
      ).compact
    end

    def pay_frequency_value(value)
      value.to_s.tr("-", "_").then do |frequency|
        {
          "weekly" => :weekly,
          "biweekly" => :bi_weekly,
          "bi_weekly" => :bi_weekly,
          "semi_monthly" => :semi_monthly,
          "semimonthly" => :semi_monthly,
          "monthly" => :monthly
        }.fetch(frequency, frequency.to_sym)
      end
    end
  end
end
