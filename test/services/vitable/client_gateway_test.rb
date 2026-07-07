require "test_helper"

module Vitable
  class ClientGatewayTest < ActiveSupport::TestCase
    test "redacts access tokens from serialized responses" do
      organization = Organization.create!(name: "Gateway Test", external_id: "org_gateway_test")
      connection = organization.integration_connections.create!(provider: "vitable", environment: "production")
      response = Data.define(:access_token, :expires_in, :token_type, :nested).new(
        access_token: "vit_at_secret_value",
        expires_in: 3_600,
        token_type: "Bearer",
        nested: { access_token: "vit_at_nested_secret" }
      )

      serialized = ClientGateway.new(connection).send(:serialize_response, response)

      assert_equal "[FILTERED]", serialized.fetch("access_token")
      assert_equal "[FILTERED]", serialized.dig("nested", "access_token")
      assert_equal 3_600, serialized.fetch("expires_in")
      assert_not_includes serialized.to_json, "vit_at_secret"
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
      assert_equal "employer_response", gateway.fetch_resource("employer", "empr_123")
      assert_equal "enrollment_response", gateway.fetch_resource("enrollment", "enrl_123")
      assert_equal "webhook_response", gateway.fetch_resource("webhook_event", "wevt_123")
      assert_equal "group_response", gateway.fetch_resource("group", "grp_123")
      assert_equal [
        [ "employee", "empl_123" ],
        [ "employer", "empr_123" ],
        [ "enrollment", "enrl_123" ],
        [ "webhook_event", "wevt_123" ],
        [ "group", "grp_123" ]
      ], calls
      assert_raises(ArgumentError) { gateway.fetch_resource("benefit_plan", "bpln_123") }
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
    ensure
      ENV.delete("VITABLE_TEST_API_KEY")
    end
  end
end
