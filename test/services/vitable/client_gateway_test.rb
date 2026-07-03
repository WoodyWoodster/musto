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
  end
end
