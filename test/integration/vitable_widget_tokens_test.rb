require "test_helper"

class VitableWidgetTokensTest < ActionDispatch::IntegrationTest
  setup do
    ENV.delete("VITABLE_CONNECT_API_KEY")
    ENV.delete("VITABLE_WIDGET_TOKEN_BROKER_SECRET")
    @organization = Organization.create!(name: "Widget Org", external_id: "org_widget")
    @employer = @organization.employers.create!(
      name: "Widget Employer",
      legal_name: "Widget Employer LLC",
      ein: "12-3456789",
      status: "active",
      vitable_id: "empr_widget_123"
    )
    @department = @employer.departments.create!(name: "People", code: "PPL")
    @location = @employer.work_locations.create!(name: "Remote", country: "US", remote: true)
    @employee = @employer.employees.create!(
      first_name: "Casey",
      last_name: "Widget",
      email: "casey.widget@example.com",
      department: @department,
      work_location: @location,
      title: "Benefits Lead",
      compensation_cents: 100_000_00,
      onboarding_status: "complete",
      vitable_id: "empl_widget_123"
    )
    @connection = @organization.integration_connections.create!(
      provider: "vitable",
      environment: "demo",
      api_key_reference: "VITABLE_CONNECT_API_KEY",
      status: "active"
    )
  end

  test "employer widget token endpoint returns a short-lived token without persisting the token value" do
    ENV["VITABLE_CONNECT_API_KEY"] = "vit_apk_test_value"
    ENV["VITABLE_WIDGET_TOKEN_BROKER_SECRET"] = "broker_secret"
    gateway = gateway_with_tokens

    with_gateway(gateway) do
      post "/api/v1/vitable/widget-tokens/employer",
           params: { requested_by: "widget_test" },
           headers: broker_headers
    end

    assert_response :created
    body = JSON.parse(response.body)
    assert_equal "vit_at_employer_secret", body.fetch("access_token")
    assert_equal "employer", body.dig("bound_entity", "type")
    assert_equal "empr_widget_123", body.dig("bound_entity", "id")

    sync = @connection.sync_runs.where(operation: "widget_token_broker", resource_type: "employer").recent_first.first
    assert_equal "succeeded", sync.status
    assert_equal "http_response", sync.stats.fetch("delivery")
    assert_equal true, sync.stats.dig("issuance", "token_present")
    assert_not_includes sync.stats.to_json, "vit_at_employer_secret"
  ensure
    ENV.delete("VITABLE_CONNECT_API_KEY")
    ENV.delete("VITABLE_WIDGET_TOKEN_BROKER_SECRET")
  end

  test "employee widget token endpoint returns an employee-bound token" do
    ENV["VITABLE_CONNECT_API_KEY"] = "vit_apk_test_value"
    ENV["VITABLE_WIDGET_TOKEN_BROKER_SECRET"] = "broker_secret"
    gateway = gateway_with_tokens

    with_gateway(gateway) do
      post "/api/v1/vitable/widget-tokens/employees/#{@employee.id}",
           params: { requested_by: "widget_test" },
           headers: broker_headers
    end

    assert_response :created
    body = JSON.parse(response.body)
    assert_equal "vit_at_employee_secret", body.fetch("access_token")
    assert_equal "employee", body.dig("bound_entity", "type")
    assert_equal "empl_widget_123", body.dig("bound_entity", "id")

    sync = @connection.sync_runs.where(operation: "widget_token_broker", resource_type: "employee").recent_first.first
    assert_equal "succeeded", sync.status
    assert_equal @employee.id, sync.stats.dig("local_record", "id")
    assert_not_includes sync.stats.to_json, "vit_at_employee_secret"
  ensure
    ENV.delete("VITABLE_CONNECT_API_KEY")
    ENV.delete("VITABLE_WIDGET_TOKEN_BROKER_SECRET")
  end

  test "employer widget token endpoint accepts a signed launch token without broker secret" do
    ENV["VITABLE_CONNECT_API_KEY"] = "vit_apk_test_value"
    gateway = gateway_with_tokens
    launch_token = Vitable::WidgetLaunchToken.issue(scope: "employer", employer_id: @employer.id)

    with_gateway(gateway) do
      post "/api/v1/vitable/widget-tokens/employer",
           params: { requested_by: "widget_test" },
           headers: launch_headers(launch_token)
    end

    assert_response :created
    body = JSON.parse(response.body)
    assert_equal "vit_at_employer_secret", body.fetch("access_token")
    assert_equal "employer", body.dig("bound_entity", "type")

    sync = @connection.sync_runs.where(operation: "widget_token_broker", resource_type: "employer").recent_first.first
    assert_equal "succeeded", sync.status
    assert_equal @employer.id, sync.stats.dig("local_record", "id")
  ensure
    ENV.delete("VITABLE_CONNECT_API_KEY")
  end

  test "employee widget token endpoint accepts a signed employee launch token" do
    ENV["VITABLE_CONNECT_API_KEY"] = "vit_apk_test_value"
    gateway = gateway_with_tokens
    launch_token = Vitable::WidgetLaunchToken.issue(scope: "employee", employer_id: @employer.id, employee_id: @employee.id)

    with_gateway(gateway) do
      post "/api/v1/vitable/widget-tokens/employees/#{@employee.id}",
           params: { requested_by: "widget_test" },
           headers: launch_headers(launch_token)
    end

    assert_response :created
    body = JSON.parse(response.body)
    assert_equal "vit_at_employee_secret", body.fetch("access_token")
    assert_equal "employee", body.dig("bound_entity", "type")

    sync = @connection.sync_runs.where(operation: "widget_token_broker", resource_type: "employee").recent_first.first
    assert_equal "succeeded", sync.status
    assert_equal @employee.id, sync.stats.dig("local_record", "id")
  ensure
    ENV.delete("VITABLE_CONNECT_API_KEY")
  end

  test "employee widget token endpoint rejects a launch token for a different employee" do
    other_employee = @employer.employees.create!(
      first_name: "Jordan",
      last_name: "Widget",
      email: "jordan.widget@example.com",
      department: @department,
      work_location: @location,
      title: "Account Manager",
      compensation_cents: 90_000_00,
      onboarding_status: "complete",
      vitable_id: "empl_widget_999"
    )
    ENV["VITABLE_CONNECT_API_KEY"] = "vit_apk_test_value"
    launch_token = Vitable::WidgetLaunchToken.issue(scope: "employee", employer_id: @employer.id, employee_id: other_employee.id)

    post "/api/v1/vitable/widget-tokens/employees/#{@employee.id}",
         params: { requested_by: "widget_test" },
         headers: launch_headers(launch_token)

    assert_response :unauthorized
    body = JSON.parse(response.body)
    assert_match "does not match", body.fetch("errors").to_sentence
    assert_nil @connection.sync_runs.find_by(operation: "widget_token_broker")
  ensure
    ENV.delete("VITABLE_CONNECT_API_KEY")
  end

  test "widget token endpoint rejects an expired launch token" do
    ENV["VITABLE_CONNECT_API_KEY"] = "vit_apk_test_value"
    launch_token = Vitable::WidgetLaunchToken.issue(
      scope: "employer",
      employer_id: @employer.id,
      expires_at: 1.minute.ago
    )

    post "/api/v1/vitable/widget-tokens/employer",
         params: { requested_by: "widget_test" },
         headers: launch_headers(launch_token)

    assert_response :unauthorized
    body = JSON.parse(response.body)
    assert_match "Widget token broker authorization", body.fetch("errors").to_sentence
    assert_nil @connection.sync_runs.find_by(operation: "widget_token_broker")
  ensure
    ENV.delete("VITABLE_CONNECT_API_KEY")
  end

  test "widget token endpoint reports missing credentials" do
    ENV["VITABLE_WIDGET_TOKEN_BROKER_SECRET"] = "broker_secret"

    post "/api/v1/vitable/widget-tokens/employer",
         params: { requested_by: "widget_test" },
         headers: broker_headers

    assert_response :unauthorized
    body = JSON.parse(response.body)
    assert_match "VITABLE_CONNECT_API_KEY", body.fetch("errors").to_sentence
    sync = @connection.sync_runs.where(operation: "widget_token_broker").recent_first.first
    assert_equal "needs_credentials", sync.status
  ensure
    ENV.delete("VITABLE_WIDGET_TOKEN_BROKER_SECRET")
  end

  test "employee widget token endpoint blocks employees without remote IDs" do
    @employee.update!(vitable_id: nil)
    ENV["VITABLE_CONNECT_API_KEY"] = "vit_apk_test_value"
    ENV["VITABLE_WIDGET_TOKEN_BROKER_SECRET"] = "broker_secret"

    post "/api/v1/vitable/widget-tokens/employees/#{@employee.id}",
         params: { requested_by: "widget_test" },
         headers: broker_headers

    assert_response :unprocessable_entity
    body = JSON.parse(response.body)
    assert_match "Vitable employee ID", body.fetch("errors").to_sentence
    sync = @connection.sync_runs.where(operation: "widget_token_broker", resource_type: "employee").recent_first.first
    assert_equal "blocked", sync.status
  ensure
    ENV.delete("VITABLE_CONNECT_API_KEY")
    ENV.delete("VITABLE_WIDGET_TOKEN_BROKER_SECRET")
  end

  test "widget token endpoint does not issue tokens when broker secret is not configured" do
    ENV["VITABLE_CONNECT_API_KEY"] = "vit_apk_test_value"

    post "/api/v1/vitable/widget-tokens/employer",
         params: { requested_by: "widget_test" },
         headers: broker_headers

    assert_response :service_unavailable
    body = JSON.parse(response.body)
    assert_match "VITABLE_WIDGET_TOKEN_BROKER_SECRET", body.fetch("errors").to_sentence
    assert_nil @connection.sync_runs.find_by(operation: "widget_token_broker")
  ensure
    ENV.delete("VITABLE_CONNECT_API_KEY")
  end

  test "widget token endpoint does not issue tokens with an invalid broker secret" do
    ENV["VITABLE_CONNECT_API_KEY"] = "vit_apk_test_value"
    ENV["VITABLE_WIDGET_TOKEN_BROKER_SECRET"] = "broker_secret"

    post "/api/v1/vitable/widget-tokens/employer",
         params: { requested_by: "widget_test" },
         headers: broker_headers("incorrect")

    assert_response :unauthorized
    body = JSON.parse(response.body)
    assert_match "Widget token broker authorization", body.fetch("errors").to_sentence
    assert_nil @connection.sync_runs.find_by(operation: "widget_token_broker")
  ensure
    ENV.delete("VITABLE_CONNECT_API_KEY")
    ENV.delete("VITABLE_WIDGET_TOKEN_BROKER_SECRET")
  end

  private

  def broker_headers(secret = "broker_secret")
    { "X-Musto-Widget-Token" => secret }
  end

  def launch_headers(token)
    { "X-Musto-Widget-Launch" => token }
  end

  def with_gateway(gateway)
    original_new = Vitable::ClientGateway.method(:new)
    Vitable::ClientGateway.define_singleton_method(:new) { |_connection| gateway }
    yield
  ensure
    Vitable::ClientGateway.define_singleton_method(:new) do |*args, **kwargs, &block|
      original_new.call(*args, **kwargs, &block)
    end
  end

  def gateway_with_tokens
    response_class = Data.define(:access_token, :expires_in, :token_type, :bound_entity)
    Object.new.tap do |gateway|
      gateway.define_singleton_method(:issue_employer_access_token) do |employer_id|
        response_class.new(
          access_token: "vit_at_employer_secret",
          expires_in: 3_600,
          token_type: "Bearer",
          bound_entity: { type: "employer", id: employer_id }
        )
      end
      gateway.define_singleton_method(:issue_employee_access_token) do |employee_id|
        response_class.new(
          access_token: "vit_at_employee_secret",
          expires_in: 3_600,
          token_type: "Bearer",
          bound_entity: { type: "employee", id: employee_id }
        )
      end
    end
  end
end
