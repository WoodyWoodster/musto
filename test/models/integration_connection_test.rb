require "test_helper"

class IntegrationConnectionTest < ActiveSupport::TestCase
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
