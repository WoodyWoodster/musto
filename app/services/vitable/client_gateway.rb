require "vitable_connect"

module Vitable
  class ClientGateway
    RETRIEVABLE_RESOURCE_TYPES = %w[
      employee
      employer
      enrollment
      webhook_event
      group
      eligibility_policy
      benefit_eligibility_policy
    ].freeze
    SDK_METHOD_COVERAGE = [
      {
        resource_class: VitableConnect::Resources::Auth,
        sdk_methods: %i[issue_access_token],
        gateway_methods: %i[issue_access_token issue_employee_access_token issue_employer_access_token],
        operations: %w[auth.issue_access_token auth.issue_employee_access_token auth.issue_employer_access_token]
      },
      {
        resource_class: VitableConnect::Resources::Employees,
        sdk_methods: %i[retrieve list_enrollments],
        gateway_methods: %i[retrieve_employee list_employee_enrollments list_all_employee_enrollments],
        operations: %w[employee.retrieve employee.list_enrollments]
      },
      {
        resource_class: VitableConnect::Resources::Employers,
        sdk_methods: %i[create retrieve list list_employees submit_census_sync update_settings],
        gateway_methods: %i[create_employer retrieve_employer list_employers list_all_employers list_employer_employees list_all_employer_employees submit_census_sync update_employer_settings],
        operations: %w[employer.create employer.retrieve employer.list employer.list_employees employer.census_sync employer.update_settings]
      },
      {
        resource_class: VitableConnect::Resources::Enrollments,
        sdk_methods: %i[retrieve],
        gateway_methods: %i[retrieve_enrollment],
        operations: %w[enrollment.retrieve]
      },
      {
        resource_class: VitableConnect::Resources::WebhookEvents,
        sdk_methods: %i[retrieve list list_deliveries],
        gateway_methods: %i[retrieve_webhook_event list_webhook_events list_all_webhook_events list_webhook_event_deliveries],
        operations: %w[webhook_event.retrieve webhook_event.list webhook_event.list_deliveries]
      },
      {
        resource_class: VitableConnect::Resources::Groups,
        sdk_methods: %i[create retrieve update list],
        gateway_methods: %i[create_group retrieve_group update_group list_groups list_all_groups],
        operations: %w[group.create group.retrieve group.update group.list]
      },
      {
        resource_class: VitableConnect::Resources::Groups::Members::Sync,
        sdk_methods: %i[submit retrieve],
        gateway_methods: %i[submit_group_member_sync retrieve_group_member_sync],
        operations: %w[group.member_sync.submit group.member_sync.retrieve]
      },
      {
        resource_class: VitableConnect::Resources::Plans,
        sdk_methods: %i[list],
        gateway_methods: %i[list_plans list_all_plans],
        operations: %w[plan.list]
      }
    ].freeze
    CUSTOM_OPERATION_COVERAGE = [
      {
        gateway_method: :create_eligibility_policy,
        operation: "employer.eligibility_policy.create",
        path: "/v1/employers/:id/benefit-eligibility-policies"
      },
      {
        gateway_method: :retrieve_eligibility_policy,
        operation: "eligibility_policy.retrieve",
        path: "/v1/benefit-eligibility-policies/:id"
      }
    ].freeze
    DOCUMENTED_WEBHOOK_EVENT_NAMES = %w[
      enrollment.accepted
      enrollment.terminated
      enrollment.elected
      enrollment.granted
      enrollment.waived
      enrollment.started
      employee.eligibility_granted
      employee.eligibility_terminated
      employee.deactivated
      employee.deduction_created
      employer.eligibility_policy_created
    ].freeze
    WEBHOOK_EVENT_NAMES = (VitableConnect::WebhookEventListParams::EventName.values.map(&:to_s) + DOCUMENTED_WEBHOOK_EVENT_NAMES).uniq.freeze
    WEBHOOK_RESOURCE_TYPES = VitableConnect::WebhookEventListParams::ResourceType.values.map(&:to_s).freeze
    WEBHOOK_PAYLOAD_ONLY_RESOURCE_TYPES = (WEBHOOK_RESOURCE_TYPES - RETRIEVABLE_RESOURCE_TYPES).freeze

    def self.retrievable_resource_type?(resource_type)
      RETRIEVABLE_RESOURCE_TYPES.include?(resource_type.to_s)
    end

    def self.webhook_resource_type?(resource_type)
      WEBHOOK_RESOURCE_TYPES.include?(resource_type.to_s)
    end

    def self.payload_only_webhook_resource_type?(resource_type)
      WEBHOOK_PAYLOAD_ONLY_RESOURCE_TYPES.include?(resource_type.to_s)
    end

    def initialize(connection, repository: IntegrationRepository.new)
      @connection = connection
      @repository = repository
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

    def issue_employer_access_token(employer_id)
      body = {
        grant_type: "client_credentials",
        bound_entity: { type: "employer", id: employer_id }
      }

      instrument("auth.issue_employer_access_token", :post, "/v1/auth/access-tokens", request_body: body) do
        client.auth.issue_access_token(
          grant_type: :client_credentials,
          bound_entity: { type: :employer, id: employer_id }
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
      when "eligibility_policy", "benefit_eligibility_policy"
        retrieve_eligibility_policy(resource_id)
      else
        raise ArgumentError, "Vitable SDK does not expose a retrieve endpoint for #{resource_type}"
      end
    end

    def retrieve_employee(employee_id)
      instrument("employee.retrieve", :get, "/v1/employees/#{employee_id}") do
        client.employees.retrieve(employee_id)
      end
    end

    def retrieve_employer(employer_id)
      instrument("employer.retrieve", :get, "/v1/employers/#{employer_id}") do
        client.employers.retrieve(employer_id)
      end
    end

    def retrieve_enrollment(enrollment_id)
      instrument("enrollment.retrieve", :get, "/v1/enrollments/#{enrollment_id}") do
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

    def list_webhook_events(limit: 20, created_after: nil, created_before: nil, event_name: nil, resource_id: nil, resource_type: nil)
      query = webhook_events_query(limit:, created_after:, created_before:, event_name:, resource_id:, resource_type:)

      instrument("webhook_event.list", :get, "/v1/webhook-events", request_body: query) do
        client.webhook_events.list(query)
      end
    end

    def list_all_webhook_events(limit: 100, created_after: nil, created_before: nil, event_name: nil, resource_id: nil, resource_type: nil)
      query = webhook_events_query(limit:, created_after:, created_before:, event_name:, resource_id:, resource_type:)

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
        policies = client.respond_to?(:benefit_eligibility_policies) ? client.benefit_eligibility_policies : nil
        if policies.respond_to?(:create)
          policies.create(employer_id, body)
        else
          client.request(
            method: :post,
            path:,
            body:,
            model: VitableConnect::Internal::Type::Unknown
          )
        end
      end
    end

    def retrieve_eligibility_policy(policy_id)
      path = "/v1/benefit-eligibility-policies/#{policy_id}"

      instrument("eligibility_policy.retrieve", :get, path) do
        policies = client.respond_to?(:benefit_eligibility_policies) ? client.benefit_eligibility_policies : nil
        if policies.respond_to?(:retrieve)
          policies.retrieve(policy_id)
        else
          client.request(
            method: :get,
            path:,
            model: VitableConnect::Internal::Type::Unknown
          )
        end
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
        environment: @connection.sdk_environment,
        base_url: @connection.effective_api_base_url,
        max_retries: 2,
        timeout: 15
      )
    end

    def instrument(operation, method, path, request_body: {})
      started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      response = yield
      log_request(operation:, method:, path:, request_body:, response:, duration_ms: duration_since(started_at))
      @repository.record_connection_request_success(@connection, operation:, method:, path:)
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
        request_body: PayloadRedactor.redact(request_body.deep_stringify_keys),
        response_body: response_body_for(response:, error:),
        error_class: error&.class&.name,
        error_message: PayloadRedactor.error_message(error)
      )
    end

    def duration_since(started_at)
      ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at) * 1000).round
    end

    def serialize_response(response)
      serialized = normalized_response_payload(response)

      PayloadRedactor.redact(serialized.deep_stringify_keys)
    end

    def response_body_for(response:, error:)
      return serialize_response(response) unless response.nil?
      return serialize_response(error.body) if error.respond_to?(:body) && !error.body.nil?

      {}
    end

    def normalized_response_payload(response)
      case response
      when nil
        {}
      when Hash
        response
      when Array
        { data: response }
      when String, Numeric, TrueClass, FalseClass
        { value: response }
      else
        if response.respond_to?(:deep_to_h)
          response.deep_to_h
        elsif response.respond_to?(:to_h)
          response.to_h
        else
          { value: response.to_s }
        end
      end
    end

    def page_response(page)
      { data: collect_page_data(page) }
    end

    def collect_page_data(page)
      return [] if page.blank?

      if page.respond_to?(:auto_paging_each)
        items = []
        index = 0
        page.auto_paging_each do |item|
          items << serialize_collection_item(item, index:)
          index += 1
        end
        items
      else
        data = page_data(page)
        raise ArgumentError, "Vitable paginated response data must be an array" unless data.is_a?(Array)

        data.each_with_index.map { |item, index| serialize_collection_item(item, index:) }
      end
    end

    def page_data(page)
      return page.data if page.respond_to?(:data)

      serialized = page.respond_to?(:deep_to_h) ? page.deep_to_h : page.to_h
      serialized.fetch(:data, serialized.fetch("data", []))
    end

    def serialize_collection_item(item, index:)
      unless item.respond_to?(:to_h) || item.respond_to?(:deep_to_h)
        raise ArgumentError, "Vitable paginated response item #{index + 1} was not a resource object"
      end

      serialize_response(item)
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

    def webhook_events_query(limit:, created_after:, created_before:, event_name:, resource_id:, resource_type:)
      {
        limit:,
        created_after:,
        created_before:,
        event_name: webhook_event_name_value(event_name),
        resource_id: resource_id.presence,
        resource_type: webhook_resource_type_value(resource_type)
      }.compact
    end

    def webhook_event_name_value(value)
      webhook_filter_value(value, supported_values: WEBHOOK_EVENT_NAMES, filter_name: "event_name")
    end

    def webhook_resource_type_value(value)
      webhook_filter_value(value, supported_values: WEBHOOK_RESOURCE_TYPES, filter_name: "resource_type")
    end

    def webhook_filter_value(value, supported_values:, filter_name:)
      normalized = value.to_s.presence
      return if normalized.blank?
      unless supported_values.include?(normalized)
        raise ArgumentError, "Vitable webhook #{filter_name} filter #{normalized} is not supported by the installed SDK"
      end

      normalized.to_sym
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
