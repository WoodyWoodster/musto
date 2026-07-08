require "test_helper"

class IntegrationConnectionTest < ActiveSupport::TestCase
  test "defaults new Vitable connections to the demo API target" do
    organization = Organization.create!(name: "Integration Demo Org", external_id: "integration_demo_org")
    connection = organization.integration_connections.create!(provider: "vitable")

    assert_equal "demo", connection.environment
    assert_equal "https://api.demo.vitablehealth.com", connection.effective_api_base_url
    assert_nil connection.sdk_environment
  end

  test "passes production through to the SDK when no base URL override is present" do
    organization = Organization.create!(name: "Integration Production Org", external_id: "integration_production_org")
    connection = organization.integration_connections.create!(provider: "vitable", environment: "production")

    assert_nil connection.effective_api_base_url
    assert_equal "production", connection.sdk_environment
  end

  test "reports webhook secret presence without exposing the value in DTOs" do
    organization = Organization.create!(name: "Integration Secret Org", external_id: "integration_secret_org")
    connection = organization.integration_connections.create!(
      provider: "vitable",
      environment: "production",
      webhook_secret_reference: "VITABLE_WEBHOOK_SECRET_TEST"
    )
    ENV["VITABLE_WEBHOOK_SECRET_TEST"] = "whsec_model_value"

    assert connection.webhook_secret_present?
    assert_equal "whsec_model_value", connection.webhook_secret
  ensure
    ENV.delete("VITABLE_WEBHOOK_SECRET_TEST")
  end
end
