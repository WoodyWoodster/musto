require "test_helper"

class VitableWebhooksTest < ActionDispatch::IntegrationTest
  setup do
    ENV.delete("VITABLE_CONNECT_API_KEY")
    ENV.delete("VITABLE_WEBHOOK_SECRET")
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
    assert_equal "not_configured", event.metadata.dig("signature_verification", "status")
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

  test "fetches and stores current resource snapshot when credentials are present" do
    ENV["VITABLE_CONNECT_API_KEY"] = "vit_apk_test_value"
    gateway_class = Class.new do
      define_method(:initialize) { |_connection| }
      define_method(:fetch_resource) do |resource_type, resource_id|
        {
          data: {
            id: resource_id,
            resource_type:,
            status: "accepted",
            access_token: "vit_at_never_store"
          }
        }
      end
    end

    result = Vitable::ProcessWebhookCommand.new(
      payload: webhook_payload.merge(event_id: "wevt_test_fetch_snapshot"),
      gateway_class:
    ).call

    assert result.success?
    event = WebhookEvent.find_by!(event_id: "wevt_test_fetch_snapshot")
    snapshot = event.metadata.fetch("resource_snapshot")
    sync_run = @connection.sync_runs.where(operation: "fetch").recent_first.first

    assert_equal "processed", event.status
    assert_not_nil event.processed_at
    assert_equal "enrollment", snapshot.fetch("resource_type")
    assert_equal "enrl_test_123", snapshot.fetch("resource_id")
    assert_equal "accepted", snapshot.dig("response", "data", "status")
    assert_equal "[FILTERED]", snapshot.dig("response", "data", "access_token")
    assert_equal "[FILTERED]", sync_run.stats.dig("remote_response", "data", "access_token")
  ensure
    ENV.delete("VITABLE_CONNECT_API_KEY")
  end

  test "accepts a signed Vitable webhook when webhook secret is configured" do
    @connection.update!(webhook_secret_reference: "VITABLE_WEBHOOK_SECRET")
    ENV["VITABLE_WEBHOOK_SECRET"] = "whsec_test_value"
    payload = webhook_payload.merge(event_id: "wevt_test_signed")
    raw_body = payload.to_json
    timestamp = "2026-01-23T14:31:00+00:00"
    signature = Vitable::WebhookSignatureVerifier.sign(raw_body:, secret: ENV.fetch("VITABLE_WEBHOOK_SECRET"), timestamp:)

    assert_difference "WebhookEvent.count", 1 do
      post api_v1_webhooks_vitable_path,
        params: payload,
        headers: signed_headers(timestamp:, signature:),
        as: :json
    end

    assert_response :accepted
    response_payload = JSON.parse(response.body)
    assert_equal "verified", response_payload.fetch("signature")
    event = WebhookEvent.find_by!(event_id: payload.fetch(:event_id))
    assert_equal "verified", event.metadata.dig("signature_verification", "status")
    assert_equal "X-Vitable-Signature", event.metadata.dig("signature_verification", "header_name")
  ensure
    ENV.delete("VITABLE_WEBHOOK_SECRET")
  end

  test "rejects invalid signatures when webhook secret is configured" do
    @connection.update!(webhook_secret_reference: "VITABLE_WEBHOOK_SECRET")
    ENV["VITABLE_WEBHOOK_SECRET"] = "whsec_test_value"
    payload = webhook_payload.merge(event_id: "wevt_test_invalid_signature")

    assert_no_difference "WebhookEvent.count" do
      post api_v1_webhooks_vitable_path,
        params: payload,
        headers: signed_headers(timestamp: "2026-01-23T14:31:00+00:00", signature: "not-a-valid-signature"),
        as: :json
    end

    assert_response :unauthorized
    response_payload = JSON.parse(response.body)
    assert_equal "signature_invalid", response_payload.fetch("signature")
  ensure
    ENV.delete("VITABLE_WEBHOOK_SECRET")
  end

  test "rejects missing signatures when webhook secret is configured" do
    @connection.update!(webhook_secret_reference: "VITABLE_WEBHOOK_SECRET")
    ENV["VITABLE_WEBHOOK_SECRET"] = "whsec_test_value"

    assert_no_difference "WebhookEvent.count" do
      post api_v1_webhooks_vitable_path,
        params: webhook_payload.merge(event_id: "wevt_test_missing_signature"),
        as: :json
    end

    assert_response :unauthorized
    response_payload = JSON.parse(response.body)
    assert_equal "missing_signature", response_payload.fetch("signature")
  ensure
    ENV.delete("VITABLE_WEBHOOK_SECRET")
  end

  private

  def signed_headers(timestamp:, signature:)
    {
      "CONTENT_TYPE" => "application/json",
      "X-Vitable-Timestamp" => timestamp,
      "X-Vitable-Signature" => "sha256=#{signature}"
    }
  end

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
