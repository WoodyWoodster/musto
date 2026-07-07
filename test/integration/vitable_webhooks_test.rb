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

  test "reconciles fetched employee resources into the local directory" do
    employer = @organization.employers.create!(name: "Webhook Employer", status: "active")
    employee = employer.employees.create!(first_name: "Casey", last_name: "Nguyen", email: "casey@example.com")
    ENV["VITABLE_CONNECT_API_KEY"] = "vit_apk_test_value"
    gateway_class = Class.new do
      define_method(:initialize) { |_connection| }
      define_method(:fetch_resource) do |_resource_type, resource_id|
        {
          data: {
            id: resource_id,
            reference_id: "musto_employee_#{Employee.find_by!(email: "casey@example.com").id}",
            email: "casey@example.com",
            status: "active",
            member_id: "mem_remote_casey"
          }
        }
      end
    end

    result = Vitable::ProcessWebhookCommand.new(
      payload: webhook_payload.merge(
        event_id: "wevt_test_employee_reconcile",
        event_name: "employee.eligibility_granted",
        resource_type: "employee",
        resource_id: "empl_remote_casey"
      ),
      gateway_class:
    ).call

    assert result.success?
    employee.reload
    event = WebhookEvent.find_by!(event_id: "wevt_test_employee_reconcile")
    reconciliation = event.metadata.fetch("resource_reconciliation")

    assert_equal "empl_remote_casey", employee.vitable_id
    assert_equal "active", employee.metadata.fetch("vitable_remote_status")
    assert_equal "mem_remote_casey", employee.metadata.fetch("vitable_member_id")
    assert_equal "granted", employee.metadata.fetch("vitable_eligibility_status")
    assert_equal "matched", reconciliation.fetch("status")
    assert_equal "Employee", reconciliation.fetch("local_record_type")
    assert_equal employee.id, reconciliation.fetch("local_record_id")
    assert_equal "reference_id", reconciliation.fetch("matched_by")
  ensure
    ENV.delete("VITABLE_CONNECT_API_KEY")
  end

  test "reconciles fetched enrollment resources into local enrollment state" do
    employer = @organization.employers.create!(name: "Enrollment Employer", status: "active")
    employee = employer.employees.create!(
      first_name: "Casey",
      last_name: "Nguyen",
      email: "casey.enrollment@example.com",
      vitable_id: "empl_remote_casey"
    )
    plan = employer.benefit_plans.create!(
      name: "Vitable Care",
      category: "direct_primary_care",
      carrier: "Vitable",
      vitable_id: "plan_remote_care"
    )
    enrollment = employee.enrollments.create!(benefit_plan: plan, status: "pending")
    ENV["VITABLE_CONNECT_API_KEY"] = "vit_apk_test_value"
    gateway_class = Class.new do
      define_method(:initialize) { |_connection| }
      define_method(:fetch_resource) do |_resource_type, resource_id|
        {
          data: {
            id: resource_id,
            employee_id: "empl_remote_casey",
            plan_id: "plan_remote_care",
            status: "accepted"
          }
        }
      end
    end

    result = Vitable::ProcessWebhookCommand.new(
      payload: webhook_payload.merge(event_id: "wevt_test_enrollment_reconcile"),
      gateway_class:
    ).call

    assert result.success?
    enrollment.reload
    event = WebhookEvent.find_by!(event_id: "wevt_test_enrollment_reconcile")
    reconciliation = event.metadata.fetch("resource_reconciliation")

    assert_equal "enrl_test_123", enrollment.vitable_id
    assert_equal "accepted", enrollment.status
    assert_not_nil enrollment.accepted_at
    assert_equal "accepted", enrollment.metadata.fetch("vitable_remote_status")
    assert_equal "empl_remote_casey", enrollment.metadata.fetch("vitable_remote_employee_id")
    assert_equal "plan_remote_care", enrollment.metadata.fetch("vitable_remote_plan_id")
    assert_equal "matched", reconciliation.fetch("status")
    assert_equal "Enrollment", reconciliation.fetch("local_record_type")
    assert_equal enrollment.id, reconciliation.fetch("local_record_id")
    assert_equal "employee_id+plan_id", reconciliation.fetch("matched_by")
  ensure
    ENV.delete("VITABLE_CONNECT_API_KEY")
  end

  test "reconciles fetched employer resources into local employer settings" do
    employer = @organization.employers.create!(name: "Policy Employer", status: "active")
    ENV["VITABLE_CONNECT_API_KEY"] = "vit_apk_test_value"
    gateway_class = Class.new do
      define_method(:initialize) { |_connection| }
      define_method(:fetch_resource) do |_resource_type, resource_id|
        {
          data: {
            id: resource_id,
            reference_id: "musto_employer_#{Employer.find_by!(name: "Policy Employer").id}",
            name: "Policy Employer",
            status: "active"
          }
        }
      end
    end

    result = Vitable::ProcessWebhookCommand.new(
      payload: webhook_payload.merge(
        event_id: "wevt_test_employer_reconcile",
        event_name: "employer.eligibility_policy_created",
        resource_type: "employer",
        resource_id: "empr_remote_policy"
      ),
      gateway_class:
    ).call

    assert result.success?
    employer.reload
    event = WebhookEvent.find_by!(event_id: "wevt_test_employer_reconcile")
    reconciliation = event.metadata.fetch("resource_reconciliation")

    assert_equal "empr_remote_policy", employer.vitable_id
    assert_equal "active", employer.settings.fetch("vitable_remote_status")
    assert_equal "wevt_test_employer_reconcile", employer.settings.fetch("vitable_eligibility_policy_last_event").fetch("event_id")
    assert_equal "matched", reconciliation.fetch("status")
    assert_equal "Employer", reconciliation.fetch("local_record_type")
    assert_equal employer.id, reconciliation.fetch("local_record_id")
    assert_equal "reference_id", reconciliation.fetch("matched_by")
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

  test "rejects webhooks when a configured secret is unavailable" do
    @connection.update!(webhook_secret_reference: "VITABLE_WEBHOOK_SECRET")

    assert_no_difference "WebhookEvent.count" do
      post api_v1_webhooks_vitable_path,
        params: webhook_payload.merge(event_id: "wevt_test_secret_missing"),
        as: :json
    end

    assert_response :unauthorized
    response_payload = JSON.parse(response.body)
    assert_equal "secret_missing", response_payload.fetch("signature")
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
