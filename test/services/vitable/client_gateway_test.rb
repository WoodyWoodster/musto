require "test_helper"

module Vitable
  class ClientGatewayTest < ActiveSupport::TestCase
    test "documents every installed Vitable SDK endpoint method" do
      ignored_subresources = {
        VitableConnect::Resources::Groups => %i[members]
      }
      documented_methods = ClientGateway::SDK_METHOD_COVERAGE.flat_map do |entry|
        entry.fetch(:sdk_methods).map { |method_name| [ entry.fetch(:resource_class).name, method_name.to_s ] }
      end
      installed_methods = ClientGateway::SDK_METHOD_COVERAGE.flat_map do |entry|
        resource_class = entry.fetch(:resource_class)
        ignored = ignored_subresources.fetch(resource_class, [])
        (resource_class.public_instance_methods(false) - [ :initialize ] - ignored).map do |method_name|
          [ resource_class.name, method_name.to_s ]
        end
      end

      assert_equal installed_methods.sort, documented_methods.sort
    end

    test "SDK coverage registry points at real gateway methods and endpoint catalog operations" do
      gateway_methods = ClientGateway.public_instance_methods(false)
      missing_gateway_methods = (
        ClientGateway::SDK_METHOD_COVERAGE.flat_map { |entry| entry.fetch(:gateway_methods) } +
        ClientGateway::CUSTOM_OPERATION_COVERAGE.map { |entry| entry.fetch(:gateway_method) }
      ).uniq - gateway_methods
      catalog_operations = ConnectionDetailDto.endpoint_catalog.flat_map { |endpoint| endpoint.fetch(:operations) }.uniq
      missing_catalog_operations = (
        ClientGateway::SDK_METHOD_COVERAGE.flat_map { |entry| entry.fetch(:operations) } +
        ClientGateway::CUSTOM_OPERATION_COVERAGE.map { |entry| entry.fetch(:operation) }
      ).uniq - catalog_operations

      assert_empty missing_gateway_methods
      assert_empty missing_catalog_operations
    end

    test "classifies SDK webhook resources without retrieve endpoints as payload only" do
      assert_equal %w[dependent payroll_deduction plan_year], ClientGateway::WEBHOOK_PAYLOAD_ONLY_RESOURCE_TYPES.sort
      assert ClientGateway.webhook_resource_type?("payroll_deduction")
      assert ClientGateway.payload_only_webhook_resource_type?("payroll_deduction")
      assert_not ClientGateway.payload_only_webhook_resource_type?("employee")
      assert_not ClientGateway.webhook_resource_type?("benefit_plan")
    end

    test "redacts sensitive values from serialized responses" do
      organization = Organization.create!(name: "Gateway Test", external_id: "org_gateway_test")
      connection = organization.integration_connections.create!(provider: "vitable", environment: "production")
      response = Data.define(:access_token, :expires_in, :token_type, :nested, :signature).new(
        access_token: "vit_at_secret_value",
        expires_in: 3_600,
        token_type: "Bearer",
        nested: {
          access_token: "vit_at_nested_secret",
          launch_token: "launch_secret_value",
          api_key: "vit_apk_secret_value",
          token_type: "Bearer"
        },
        signature: "vitable_signature_secret"
      )

      serialized = ClientGateway.new(connection).send(:serialize_response, response)

      assert_equal "[FILTERED]", serialized.fetch("access_token")
      assert_equal "[FILTERED]", serialized.dig("nested", "access_token")
      assert_equal "[FILTERED]", serialized.dig("nested", "launch_token")
      assert_equal "[FILTERED]", serialized.dig("nested", "api_key")
      assert_equal "[FILTERED]", serialized.fetch("signature")
      assert_equal "Bearer", serialized.dig("nested", "token_type")
      assert_equal 3_600, serialized.fetch("expires_in")
      assert_not_includes serialized.to_json, "vit_at_secret"
      assert_not_includes serialized.to_json, "launch_secret_value"
      assert_not_includes serialized.to_json, "vit_apk_secret_value"
      assert_not_includes serialized.to_json, "vitable_signature_secret"
    end

    test "redacts sensitive values from logged request bodies" do
      organization = Organization.create!(name: "Gateway Request Redaction Test", external_id: "org_gateway_request_redaction_test")
      connection = organization.integration_connections.create!(provider: "vitable", environment: "production")
      gateway = ClientGateway.new(connection)

      gateway.send(
        :log_request,
        operation: "test.redaction",
        method: :post,
        path: "/v1/test",
        duration_ms: 12,
        request_body: {
          access_token: "vit_at_request_secret",
          nested: {
            client_secret: "client_secret_value",
            token_type: "Bearer"
          }
        },
        response: { ok: true }
      )

      log = connection.api_request_logs.last

      assert_equal "[FILTERED]", log.request_body.fetch("access_token")
      assert_equal "[FILTERED]", log.request_body.dig("nested", "client_secret")
      assert_equal "Bearer", log.request_body.dig("nested", "token_type")
      assert_not_includes log.request_body.to_json, "vit_at_request_secret"
      assert_not_includes log.request_body.to_json, "client_secret_value"
    end

    test "logs redacted SDK status error bodies" do
      organization = Organization.create!(name: "Gateway Error Body Test", external_id: "org_gateway_error_body_test")
      connection = organization.integration_connections.create!(provider: "vitable", environment: "demo")
      gateway = ClientGateway.new(connection)
      auth = Object.new
      auth.define_singleton_method(:issue_access_token) do |_params|
        raise VitableConnect::Errors::AuthenticationError.new(
          url: URI("https://api.demo.vitablehealth.com/v1/auth/access-tokens"),
          status: 401,
          headers: {},
          body: {
            error: "invalid_api_key",
            api_key: "vit_apk_bad_error_body",
            details: [ { access_token: "vit_at_bad_error_body", reason: "expired" } ]
          },
          request: nil,
          response: nil
        )
      end
      fake_client = Object.new
      fake_client.define_singleton_method(:auth) { auth }
      gateway.define_singleton_method(:client) { fake_client }

      assert_raises(VitableConnect::Errors::AuthenticationError) { gateway.issue_access_token }

      log = connection.api_request_logs.last
      assert_equal 401, log.status_code
      assert_equal "VitableConnect::Errors::AuthenticationError", log.error_class
      assert_equal "invalid_api_key", log.response_body.fetch("error")
      assert_equal "[FILTERED]", log.response_body.fetch("api_key")
      assert_equal "[FILTERED]", log.response_body.dig("details", 0, "access_token")
      assert_equal "expired", log.response_body.dig("details", 0, "reason")
      assert_not_includes log.response_body.to_json, "vit_apk_bad_error_body"
      assert_not_includes log.response_body.to_json, "vit_at_bad_error_body"
    end

    test "normalizes employer provisioning payloads for the SDK" do
      organization = Organization.create!(name: "Gateway Payload Test", external_id: "org_gateway_payload_test")
      connection = organization.integration_connections.create!(provider: "vitable", environment: "production")
      gateway = ClientGateway.new(connection)

      payload = gateway.send(:employer_create_payload, {
        "name" => "Ops Employer",
        "address" => {
          "address_line_1" => "214 Market Street",
          "city" => "Philadelphia",
          "state" => "PA",
          "zipcode" => "19106"
        }
      })

      assert_equal "Ops Employer", payload.fetch(:name)
      assert_equal "PA", payload.dig(:address, :state)
      assert_equal :bi_weekly, gateway.send(:pay_frequency_value, "bi_weekly")
      assert_equal :semi_monthly, gateway.send(:pay_frequency_value, "semimonthly")
    end

    test "submits eligibility policy through authenticated custom request" do
      organization = Organization.create!(name: "Gateway Capability Test", external_id: "org_gateway_capability_test")
      connection = organization.integration_connections.create!(provider: "vitable", environment: "production")
      gateway = ClientGateway.new(connection)
      requests = []
      fake_client = Object.new
      fake_client.define_singleton_method(:request) do |request|
        requests << request
        { data: { id: "elig_policy_123" } }
      end
      gateway.define_singleton_method(:client) { fake_client }

      response = gateway.create_eligibility_policy("empr_123", {
        "classification" => "All",
        "waiting_period" => "30 days",
        "ignored" => true
      })

      assert_equal "elig_policy_123", response.dig(:data, :id)
      request = requests.first
      assert_equal :post, request.fetch(:method)
      assert_equal "/v1/employers/empr_123/benefit-eligibility-policies", request.fetch(:path)
      assert_equal({ classification: "All", waiting_period: "30 days" }, request.fetch(:body))

      log = connection.api_request_logs.last
      assert_equal "employer.eligibility_policy.create", log.operation
      assert_equal "/v1/employers/empr_123/benefit-eligibility-policies", log.path
      assert_equal "All", log.request_body.fetch("classification")
    end

    test "marks the connection active after any successful Vitable request" do
      organization = Organization.create!(name: "Gateway Status Test", external_id: "org_gateway_status_test")
      connection = organization.integration_connections.create!(
        provider: "vitable",
        environment: "production",
        status: "needs_credentials"
      )
      gateway = ClientGateway.new(connection)
      auth = Object.new
      auth.define_singleton_method(:issue_access_token) do |_params|
        { access_token: "vit_at_status_secret", expires_in: 3_600 }
      end
      fake_client = Object.new
      fake_client.define_singleton_method(:auth) { auth }
      gateway.define_singleton_method(:client) { fake_client }

      gateway.issue_access_token

      connection.reload
      assert_equal "active", connection.status
      assert_not_nil connection.last_synced_at
      assert_equal "auth.issue_access_token", connection.metadata.dig("last_successful_request", "operation")
      assert_equal "POST", connection.metadata.dig("last_successful_request", "method")
      assert_equal "/v1/auth/access-tokens", connection.metadata.dig("last_successful_request", "path")
    end

    test "issues employer-bound access tokens for admin widgets" do
      organization = Organization.create!(name: "Gateway Employer Token Test", external_id: "org_gateway_employer_token_test")
      connection = organization.integration_connections.create!(provider: "vitable", environment: "production")
      gateway = ClientGateway.new(connection)
      calls = []
      auth = Object.new
      auth.define_singleton_method(:issue_access_token) do |params|
        calls << params
        { access_token: "vit_at_secret_value", expires_in: 3_600, bound_entity: params.fetch(:bound_entity) }
      end
      fake_client = Object.new
      fake_client.define_singleton_method(:auth) { auth }
      gateway.define_singleton_method(:client) { fake_client }

      response = gateway.issue_employer_access_token("empr_123")

      assert_equal :client_credentials, calls.first.fetch(:grant_type)
      assert_equal({ type: :employer, id: "empr_123" }, calls.first.fetch(:bound_entity))
      assert_equal "vit_at_secret_value", response.fetch(:access_token)
      log = connection.api_request_logs.last
      assert_equal "auth.issue_employer_access_token", log.operation
      assert_equal "employer", log.request_body.dig("bound_entity", "type")
      assert_equal "[FILTERED]", log.response_body.fetch("access_token")
    end

    test "normalizes group member sync payloads for the SDK" do
      organization = Organization.create!(name: "Gateway Group Payload Test", external_id: "org_gateway_group_payload_test")
      connection = organization.integration_connections.create!(provider: "vitable", environment: "production")
      gateway = ClientGateway.new(connection)

      payload = gateway.send(:group_member_payload, {
        "reference_id" => "musto_employee_123",
        "first_name" => "Casey",
        "last_name" => "Ng",
        "email" => "casey@example.com",
        "phone" => "5551234567",
        "date_of_birth" => "1990-01-15",
        "plan_id" => "plan_care_123",
        "address" => {
          "address_line_1" => "214 Market Street",
          "city" => "Philadelphia",
          "state" => "PA",
          "zipcode" => "19106"
        }
      })

      assert_equal "musto_employee_123", payload.fetch(:reference_id)
      assert_equal Date.new(1990, 1, 15), payload.fetch(:date_of_birth)
      assert_equal "plan_care_123", payload.fetch(:plan_id)
      assert_equal "PA", payload.dig(:address, :state)
    end

    test "collects and serializes every auto-paginated list item" do
      organization = Organization.create!(name: "Gateway Pagination Test", external_id: "org_gateway_pagination_test")
      connection = organization.integration_connections.create!(provider: "vitable", environment: "production")
      item_class = Data.define(:id, :name, :nested)
      page = Object.new
      page.define_singleton_method(:auto_paging_each) do |&block|
        block.call(item_class.new(id: "plan_first", name: "Primary Care", nested: { access_token: "vit_at_nested" }))
        block.call({ id: "plan_second", name: "Dental" })
      end

      response = ClientGateway.new(connection).send(:page_response, page)

      assert_equal [ "plan_first", "plan_second" ], response.fetch(:data).map { |item| item.fetch("id") }
      assert_equal "[FILTERED]", response.dig(:data, 0, "nested", "access_token")
    end

    test "rejects list responses with non-array data" do
      organization = Organization.create!(name: "Gateway Pagination Shape Test", external_id: "org_gateway_pagination_shape_test")
      connection = organization.integration_connections.create!(provider: "vitable", environment: "production")
      page_class = Data.define(:data)
      page = page_class.new(data: { id: "plan_single_object" })

      error = assert_raises(ArgumentError) do
        ClientGateway.new(connection).send(:page_response, page)
      end

      assert_match "paginated response data must be an array", error.message
    end

    test "rejects auto-paginated items that are not resource objects" do
      organization = Organization.create!(name: "Gateway Pagination Item Test", external_id: "org_gateway_pagination_item_test")
      connection = organization.integration_connections.create!(provider: "vitable", environment: "production")
      page = Object.new
      page.define_singleton_method(:auto_paging_each) do |&block|
        block.call("plan_scalar")
      end

      error = assert_raises(ArgumentError) do
        ClientGateway.new(connection).send(:page_response, page)
      end

      assert_match "paginated response item 1 was not a resource object", error.message
    end

    test "passes webhook event filters to the SDK list call" do
      organization = Organization.create!(name: "Gateway Webhook Filter Test", external_id: "org_gateway_webhook_filter_test")
      connection = organization.integration_connections.create!(provider: "vitable", environment: "production")
      gateway = ClientGateway.new(connection)
      created_after = Time.zone.parse("2026-02-01T12:00:00Z")
      created_before = Time.zone.parse("2026-02-02T12:00:00Z")
      calls = []
      webhook_events = Object.new
      response_class = Data.define(:data)
      webhook_events.define_singleton_method(:list) do |query|
        calls << query
        response_class.new(data: [])
      end
      fake_client = Object.new
      fake_client.define_singleton_method(:webhook_events) { webhook_events }
      gateway.define_singleton_method(:client) { fake_client }

      gateway.list_all_webhook_events(
        limit: 25,
        created_after:,
        created_before:,
        event_name: "employee.deduction_created",
        resource_id: "empl_123",
        resource_type: "employee"
      )

      assert_equal(
        {
          limit: 25,
          created_after:,
          created_before:,
          event_name: :"employee.deduction_created",
          resource_id: "empl_123",
          resource_type: :employee
        },
        calls.first
      )
      log = connection.api_request_logs.last
      assert_equal "webhook_event.list", log.operation
      assert_equal "/v1/webhook-events", log.path
      assert_equal "employee.deduction_created", log.request_body.fetch("event_name")
      assert_equal "employee", log.request_body.fetch("resource_type")
    end

    test "rejects unsupported webhook list filters before SDK calls" do
      organization = Organization.create!(name: "Gateway Webhook Filter Guard Test", external_id: "org_gateway_webhook_filter_guard_test")
      connection = organization.integration_connections.create!(provider: "vitable", environment: "production")
      gateway = ClientGateway.new(connection)

      assert_raises(ArgumentError, match: /event_name filter group.updated/) do
        gateway.list_webhook_events(event_name: "group.updated")
      end
      assert_raises(ArgumentError, match: /resource_type filter group/) do
        gateway.list_webhook_events(resource_type: "group")
      end
      assert_empty connection.api_request_logs
    end

    test "dispatches generic resource fetches to typed SDK retrieve methods" do
      organization = Organization.create!(name: "Gateway Fetch Test", external_id: "org_gateway_fetch_test")
      connection = organization.integration_connections.create!(provider: "vitable", environment: "production")
      gateway = ClientGateway.new(connection)
      calls = []

      gateway.define_singleton_method(:retrieve_employee) { |id| calls << [ "employee", id ]; "employee_response" }
      gateway.define_singleton_method(:retrieve_employer) { |id| calls << [ "employer", id ]; "employer_response" }
      gateway.define_singleton_method(:retrieve_enrollment) { |id| calls << [ "enrollment", id ]; "enrollment_response" }
      gateway.define_singleton_method(:retrieve_webhook_event) { |id| calls << [ "webhook_event", id ]; "webhook_response" }
      gateway.define_singleton_method(:retrieve_group) { |id| calls << [ "group", id ]; "group_response" }

      assert_equal "employee_response", gateway.fetch_resource("employee", "empl_123")
      assert ClientGateway.retrievable_resource_type?("employee")
      assert_equal "employer_response", gateway.fetch_resource("employer", "empr_123")
      assert_equal "enrollment_response", gateway.fetch_resource("enrollment", "enrl_123")
      assert_equal "webhook_response", gateway.fetch_resource("webhook_event", "wevt_123")
      assert_equal "group_response", gateway.fetch_resource("group", "grp_123")
      assert_not ClientGateway.retrievable_resource_type?("payroll_deduction")
      assert_equal [
        [ "employee", "empl_123" ],
        [ "employer", "empr_123" ],
        [ "enrollment", "enrl_123" ],
        [ "webhook_event", "wevt_123" ],
        [ "group", "grp_123" ]
      ], calls
      assert_raises(ArgumentError) { gateway.fetch_resource("benefit_plan", "bpln_123") }
    end

    test "logs typed retrieve operations for Vitable resources" do
      organization = Organization.create!(name: "Gateway Retrieve Logs Test", external_id: "org_gateway_retrieve_logs_test")
      connection = organization.integration_connections.create!(provider: "vitable", environment: "production")
      gateway = ClientGateway.new(connection)

      employees = Object.new
      employees.define_singleton_method(:retrieve) { |id| { data: { id: } } }
      employers = Object.new
      employers.define_singleton_method(:retrieve) { |id| { data: { id: } } }
      enrollments = Object.new
      enrollments.define_singleton_method(:retrieve) { |id| { data: { id: } } }
      fake_client = Object.new
      fake_client.define_singleton_method(:employees) { employees }
      fake_client.define_singleton_method(:employers) { employers }
      fake_client.define_singleton_method(:enrollments) { enrollments }
      gateway.define_singleton_method(:client) { fake_client }

      gateway.retrieve_employee("empl_123")
      gateway.retrieve_employer("empr_123")
      gateway.retrieve_enrollment("enrl_123")

      logs = connection.api_request_logs.order(:id)
      assert_equal %w[employee.retrieve employer.retrieve enrollment.retrieve], logs.map(&:operation)
      assert_equal [ "/v1/employees/empl_123", "/v1/employers/empr_123", "/v1/enrollments/enrl_123" ], logs.map(&:path)
    end

    test "targets the Vitable demo base URL for demo connections" do
      ENV["VITABLE_TEST_API_KEY"] = "vit_apk_test"
      organization = Organization.create!(name: "Gateway Demo Test", external_id: "org_gateway_demo_test")
      connection = organization.integration_connections.create!(
        provider: "vitable",
        environment: "demo",
        api_key_reference: "VITABLE_TEST_API_KEY"
      )

      client = ClientGateway.new(connection).send(:client)

      assert_equal "https://api.demo.vitablehealth.com", client.base_url.to_s
      assert_nil connection.sdk_environment
    ensure
      ENV.delete("VITABLE_TEST_API_KEY")
    end
  end
end
