require "test_helper"

class VitableWebhooksTest < ActionDispatch::IntegrationTest
  setup do
    ENV.delete("VITABLE_CONNECT_API_KEY")
    @organization = Organization.create!(name: "Webhook Org", external_id: "org_webhook_test")
    @connection = @organization.integration_connections.create!(
      provider: "vitable",
      environment: "production",
      api_key_reference: "VITABLE_CONNECT_API_KEY",
      status: "needs_credentials"
    )
  end

  test "accepts a Vitable webhook and records missing credentials state" do
    assert_difference "WebhookEvent.count", 1 do
      post api_v1_webhooks_vitable_path, params: webhook_payload, as: :json
    end

    assert_response :accepted
    event = WebhookEvent.find_by!(event_id: webhook_payload[:event_id])
    assert_equal @connection, event.integration_connection
    assert_equal "needs_credentials", event.status
    assert_nil event.processed_at
  end

  test "does not duplicate webhook events with the same event id" do
    post api_v1_webhooks_vitable_path, params: webhook_payload, as: :json
    assert_response :accepted

    assert_no_difference "WebhookEvent.count" do
      post api_v1_webhooks_vitable_path, params: webhook_payload, as: :json
    end

    assert_response :accepted
  end

  private

  def webhook_payload
    {
      event_id: "wevt_test_accepted",
      organization_id: @organization.external_id,
      event_name: "enrollment.accepted",
      resource_type: "enrollment",
      resource_id: "enrl_test_123",
      created_at: "2026-01-23T14:30:00+00:00"
    }
  end
end
