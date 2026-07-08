require "test_helper"

class IntegrationConnectionTest < ActiveSupport::TestCase
  test "defaults new Vitable connections to the demo SDK environment" do
    organization = Organization.create!(name: "Integration Demo Org", external_id: "integration_demo_org")
    connection = organization.integration_connections.create!(provider: "vitable")

    assert_equal Vitable::Configuration::DEFAULT_ENVIRONMENT, connection.environment
    assert_equal Vitable::Configuration::DEFAULT_ENVIRONMENT, connection.sdk_environment
    assert_nil connection.configured_api_base_url
    assert_equal Vitable::Configuration::DEMO_API_BASE_URL, connection.sdk_base_url
    assert_equal Vitable::Configuration::DEMO_API_BASE_URL, connection.effective_api_base_url
  end

  test "passes production through to the SDK when no base URL override is present" do
    organization = Organization.create!(name: "Integration Production Org", external_id: "integration_production_org")
    connection = organization.integration_connections.create!(provider: "vitable", environment: "production")

    assert_nil connection.effective_api_base_url
    assert_equal "production", connection.sdk_environment
    assert_nil connection.sdk_base_url
  end

  test "uses explicit API base URL overrides without changing the SDK environment" do
    with_vitable_env(Vitable::Configuration::API_BASE_URL_ENV => "https://vitable-proxy.example.test") do
      organization = Organization.create!(name: "Integration Override Org", external_id: "integration_override_org")
      connection = organization.integration_connections.create!(provider: "vitable")

      assert_equal Vitable::Configuration::DEFAULT_ENVIRONMENT, connection.sdk_environment
      assert_equal "https://vitable-proxy.example.test", connection.configured_api_base_url
      assert_equal "https://vitable-proxy.example.test", connection.sdk_base_url
      assert_equal "https://vitable-proxy.example.test", connection.effective_api_base_url
    end
  end

  test "reports webhook secret presence without exposing the value in DTOs" do
    organization = Organization.create!(name: "Integration Secret Org", external_id: "integration_secret_org")
    connection = organization.integration_connections.create!(
      provider: "vitable",
      environment: "production",
      webhook_secret_reference: "VITABLE_WEBHOOK_SECRET_TEST"
    )
    set_vitable_env("VITABLE_WEBHOOK_SECRET_TEST" => "whsec_model_value")

    assert connection.webhook_secret_present?
    assert_equal "whsec_model_value", connection.webhook_secret
  end
end
