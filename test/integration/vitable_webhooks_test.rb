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

  test "reconciles employee deduction webhooks into payroll deductions" do
    employer = @organization.employers.create!(name: "Deduction Employer", status: "active")
    employee = employer.employees.create!(
      first_name: "Casey",
      last_name: "Nguyen",
      email: "casey.deductions@example.com",
      vitable_id: "empl_remote_casey"
    )
    plan = employer.benefit_plans.create!(
      name: "Primary Care",
      category: "direct_primary_care",
      carrier: "Vitable",
      vitable_id: "bprd_primary_care"
    )
    enrollment = employee.enrollments.create!(
      benefit_plan: plan,
      status: "accepted",
      vitable_id: "enrl_remote_primary"
    )
    payroll_run = employer.payroll_runs.create!(
      period_start_on: Date.current.beginning_of_month,
      period_end_on: Date.current.end_of_month,
      pay_date: Date.current.end_of_month,
      gross_pay_cents: 0,
      status: "estimated"
    )
    ENV["VITABLE_CONNECT_API_KEY"] = "vit_apk_test_value"
    deduction_amounts = [ 7900, 8100 ]
    gateway_class = Class.new do
      define_method(:initialize) { |_connection| }
      define_method(:fetch_resource) do |_resource_type, resource_id|
        {
          data: {
            id: resource_id,
            reference_id: "musto_employee_#{Employee.find_by!(email: "casey.deductions@example.com").id}",
            email: "casey.deductions@example.com",
            status: "active",
            deductions: [
              {
                id: "ded_remote_primary",
                enrollment_id: "enrl_remote_primary",
                plan_id: "bprd_primary_care",
                benefit_name: "Primary Care",
                deduction_amount_in_cents: deduction_amounts.shift,
                frequency: "bi_weekly",
                period_start_date: Date.current.beginning_of_month,
                period_end_date: Date.current.end_of_month,
                tax_classification: "Post-tax"
              }
            ]
          }
        }
      end
    end

    first_result = Vitable::ProcessWebhookCommand.new(
      payload: webhook_payload.merge(
        event_id: "wevt_test_employee_deduction_created",
        event_name: "employee.deduction_created",
        resource_type: "employee",
        resource_id: "empl_remote_casey"
      ),
      gateway_class:
    ).call
    second_result = nil
    assert_no_difference -> { PayrollDeduction.count } do
      second_result = Vitable::ProcessWebhookCommand.new(
        payload: webhook_payload.merge(
          event_id: "wevt_test_employee_deduction_updated",
          event_name: "employee.deduction_created",
          resource_type: "employee",
          resource_id: "empl_remote_casey"
        ),
        gateway_class:
      ).call
    end

    assert first_result.success?
    assert second_result.success?
    deduction = payroll_run.payroll_deductions.find_by!(vitable_id: "ded_remote_primary")
    assert_equal employee.id, deduction.employee_id
    assert_equal enrollment.id, deduction.enrollment_id
    assert_equal "VITABLE_PRIMARY_CARE", deduction.code
    assert_equal 8100, deduction.amount_cents
    assert_equal "ready", deduction.status
    assert_equal "bi_weekly", deduction.metadata.fetch("frequency")
    assert_equal "employee.deduction_created", deduction.metadata.fetch("last_webhook_event_name")
    assert_equal "ded_remote_primary", deduction.metadata.fetch("remote_id")
    assert_equal "employee.deduction_created", employee.reload.metadata.fetch("vitable_last_webhook_event_name")
    assert_equal 1, employee.metadata.fetch("vitable_remote_deductions").count
    reconciliation = WebhookEvent.find_by!(event_id: "wevt_test_employee_deduction_created").metadata.fetch("resource_reconciliation")
    assert_includes reconciliation.fetch("applied_changes"), "payroll_deductions.#{deduction.id}"
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
      vitable_id: "bprd_remote_care"
    )
    enrollment = employee.enrollments.create!(benefit_plan: plan, status: "pending")
    payroll_run = employer.payroll_runs.create!(
      period_start_on: Date.current.beginning_of_month,
      period_end_on: Date.current.end_of_month,
      pay_date: Date.current.end_of_month,
      gross_pay_cents: 0,
      status: "estimated"
    )
    deduction = payroll_run.payroll_deductions.create!(
      employee:,
      enrollment:,
      code: "VITABLE_CARE",
      amount_cents: 0,
      status: "waiting_on_enrollment"
    )
    answered_at = Time.current.change(usec: 0)
    coverage_start = Date.current.beginning_of_month
    ENV["VITABLE_CONNECT_API_KEY"] = "vit_apk_test_value"
    gateway_class = Class.new do
      define_method(:initialize) { |_connection| }
      define_method(:fetch_resource) do |_resource_type, resource_id|
        {
          data: {
            id: resource_id,
            employee_id: "empl_remote_casey",
            benefit: {
              id: "bprd_remote_care",
              name: "Vitable Care",
              category: "Medical",
              product_code: "VPC"
            },
            status: "enrolled",
            answered_at:,
            coverage_start:,
            coverage_end: nil,
            employee_deduction_in_cents: 7900,
            employer_contribution_in_cents: 2000
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
    assert_equal answered_at.to_i, enrollment.accepted_at.to_i
    assert_equal coverage_start, enrollment.effective_on
    assert_equal "enrolled", enrollment.metadata.fetch("vitable_remote_status")
    assert_equal "empl_remote_casey", enrollment.metadata.fetch("vitable_remote_employee_id")
    assert_equal "bprd_remote_care", enrollment.metadata.fetch("vitable_remote_plan_id")
    assert_equal "VPC", enrollment.metadata.dig("vitable_remote_benefit", "product_code")
    assert_equal 7900, enrollment.metadata.fetch("vitable_employee_deduction_cents")
    assert_equal 2000, enrollment.metadata.fetch("vitable_employer_contribution_cents")
    assert_equal 7900, deduction.reload.amount_cents
    assert_equal "ready", deduction.status
    assert_equal "matched", reconciliation.fetch("status")
    assert_equal "Enrollment", reconciliation.fetch("local_record_type")
    assert_equal enrollment.id, reconciliation.fetch("local_record_id")
    assert_equal "employee_id+plan_id", reconciliation.fetch("matched_by")
  ensure
    ENV.delete("VITABLE_CONNECT_API_KEY")
  end

  test "reconciles terminated enrollment resources as inactive and stops payroll deductions" do
    employer = @organization.employers.create!(name: "Terminated Enrollment Employer", status: "active")
    employee = employer.employees.create!(
      first_name: "Riley",
      last_name: "Terminated",
      email: "riley.enrollment@example.com",
      vitable_id: "empl_remote_riley"
    )
    plan = employer.benefit_plans.create!(
      name: "Vitable Medical",
      category: "medical",
      carrier: "Vitable",
      vitable_id: "bprd_remote_medical"
    )
    enrollment = employee.enrollments.create!(
      benefit_plan: plan,
      status: "accepted",
      accepted_at: 2.months.ago,
      effective_on: Date.current.beginning_of_month - 2.months,
      vitable_id: "enrl_remote_riley"
    )
    payroll_run = employer.payroll_runs.create!(
      period_start_on: Date.current.beginning_of_month,
      period_end_on: Date.current.end_of_month,
      pay_date: Date.current.end_of_month,
      gross_pay_cents: 0,
      status: "estimated"
    )
    deduction = payroll_run.payroll_deductions.create!(
      employee:,
      enrollment:,
      code: "VITABLE_MEDICAL",
      amount_cents: 12_500,
      status: "ready"
    )
    terminated_at = Time.current.change(usec: 0)
    coverage_end = Date.current.end_of_month
    ENV["VITABLE_CONNECT_API_KEY"] = "vit_apk_test_value"
    gateway_class = Class.new do
      define_method(:initialize) { |_connection| }
      define_method(:fetch_resource) do |_resource_type, resource_id|
        {
          data: {
            id: resource_id,
            employee_id: "empl_remote_riley",
            benefit: {
              id: "bprd_remote_medical",
              name: "Vitable Medical",
              category: "Medical",
              product_code: "MEC"
            },
            status: "inactive",
            answered_at: 2.months.ago,
            coverage_start: Date.current.beginning_of_month - 2.months,
            coverage_end:,
            terminated_at:,
            employee_deduction_in_cents: 0,
            employer_contribution_in_cents: 0
          }
        }
      end
    end

    result = Vitable::ProcessWebhookCommand.new(
      payload: webhook_payload.merge(
        event_id: "wevt_test_enrollment_terminated",
        event_name: "enrollment.terminated",
        resource_type: "enrollment",
        resource_id: "enrl_remote_riley"
      ),
      gateway_class:
    ).call

    assert result.success?
    assert_equal "inactive", enrollment.reload.status
    assert_nil enrollment.accepted_at
    assert_equal coverage_end.iso8601, enrollment.metadata.fetch("vitable_remote_coverage_end")
    assert_equal terminated_at.iso8601, enrollment.metadata.fetch("vitable_remote_terminated_at")
    assert_equal 0, deduction.reload.amount_cents
    assert_equal "inactive", deduction.status
    reconciliation = WebhookEvent.find_by!(event_id: "wevt_test_enrollment_terminated").metadata.fetch("resource_reconciliation")
    assert_equal "matched", reconciliation.fetch("status")
    assert_includes reconciliation.fetch("applied_changes"), "status"
    assert_includes reconciliation.fetch("applied_changes"), "payroll_deductions.#{deduction.id}"
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

  test "reconciles fetched group resources into care group settings" do
    employer = @organization.employers.create!(name: "Care Group Employer", status: "active")
    ENV["VITABLE_CONNECT_API_KEY"] = "vit_apk_test_value"
    gateway_class = Class.new do
      define_method(:initialize) { |_connection| }
      define_method(:fetch_resource) do |_resource_type, resource_id|
        {
          data: {
            id: resource_id,
            name: "Care Group Employer",
            external_reference_id: "musto_care_group_#{Employer.find_by!(name: "Care Group Employer").id}",
            organization_id: "org_demo_vitable",
            updated_at: Time.current.iso8601
          }
        }
      end
    end

    result = Vitable::ProcessWebhookCommand.new(
      payload: webhook_payload.merge(
        event_id: "wevt_test_group_reconcile",
        event_name: "group.updated",
        resource_type: "group",
        resource_id: "grp_remote_care"
      ),
      gateway_class:
    ).call

    assert result.success?
    employer.reload
    event = WebhookEvent.find_by!(event_id: "wevt_test_group_reconcile")
    reconciliation = event.metadata.fetch("resource_reconciliation")
    fetch_run = @connection.sync_runs.where(operation: "fetch", resource_type: "group").recent_first.first

    assert_equal "grp_remote_care", employer.settings.fetch("vitable_care_group_id")
    assert_equal "musto_care_group_#{employer.id}", employer.settings.fetch("vitable_care_group_remote_reference_id")
    assert_equal "group.updated", employer.settings.fetch("vitable_care_group_last_webhook_event_name")
    assert_equal "vitable_webhook_resource", employer.settings.fetch("vitable_care_group_snapshot_source")
    assert_equal "grp_remote_care", employer.settings.dig("vitable_care_group_snapshot", "id")
    assert_equal "matched", reconciliation.fetch("status")
    assert_equal "Employer", reconciliation.fetch("local_record_type")
    assert_equal employer.id, reconciliation.fetch("local_record_id")
    assert_equal "external_reference_id", reconciliation.fetch("matched_by")
    assert_includes reconciliation.fetch("applied_changes"), "settings.vitable_care_group_id"
    assert_equal "matched", fetch_run.stats.dig("resource_reconciliation", "status")
    assert_equal employer.id, fetch_run.stats.dig("resource_reconciliation", "local_record_id")
  ensure
    ENV.delete("VITABLE_CONNECT_API_KEY")
  end

  test "replay command audits successful credential-present reprocessing" do
    employer = @organization.employers.create!(name: "Replay Employer", status: "active")
    employee = employer.employees.create!(
      first_name: "Casey",
      last_name: "Replay",
      email: "casey.replay@example.com",
      vitable_id: "empl_replay_casey"
    )
    plan = employer.benefit_plans.create!(
      name: "Replay Primary Care",
      category: "direct_primary_care",
      carrier: "Vitable",
      vitable_id: "bprd_replay_care"
    )
    enrollment = employee.enrollments.create!(
      benefit_plan: plan,
      status: "pending",
      vitable_id: "enrl_test_123"
    )
    event = @connection.webhook_events.create!(
      event_id: "wevt_test_replay_success",
      organization_external_id: @organization.external_id,
      event_name: "enrollment.accepted",
      resource_type: "enrollment",
      resource_id: "enrl_test_123",
      occurred_at: Time.current,
      status: "failed",
      processed_at: 1.hour.ago,
      error_message: "stale failure",
      payload: webhook_payload.merge(event_id: "wevt_test_replay_success")
    )
    ENV["VITABLE_CONNECT_API_KEY"] = "vit_apk_test_value"
    gateway_class = Class.new do
      define_method(:initialize) { |_connection| }
      define_method(:fetch_resource) do |_resource_type, resource_id|
        {
          data: {
            id: resource_id,
            employee_id: "empl_replay_casey",
            benefit: {
              id: "bprd_replay_care",
              name: "Replay Primary Care",
              category: "Medical"
            },
            status: "enrolled",
            answered_at: Time.current,
            coverage_start: Date.current,
            employee_deduction_in_cents: 7900,
            access_token: "vit_at_never_store"
          }
        }
      end
    end

    result = Vitable::ReplayWebhookEventCommand.new(
      dto: Vitable::ReplayWebhookEventDto.new(webhook_event_id: event.id, requested_by: "integration_admin"),
      gateway_class:
    ).call

    assert result.success?
    assert_equal "processed", event.reload.status
    assert_not_nil event.processed_at
    assert_nil event.error_message
    assert_equal "accepted", enrollment.reload.status
    replay_run = @connection.sync_runs.where(operation: "webhook_replay").recent_first.first
    fetch_run = @connection.sync_runs.where(operation: "fetch", resource_type: "enrollment").recent_first.first
    assert_equal "succeeded", replay_run.status
    assert_equal "integration_admin", replay_run.stats.fetch("requested_by")
    assert_equal "failed", replay_run.stats.fetch("previous_status")
    assert_equal "processed", replay_run.stats.fetch("final_status")
    assert_equal event.event_id, replay_run.stats.fetch("resource_id")
    assert_equal "[FILTERED]", replay_run.stats.dig("result", "data", "access_token")
    assert_equal "succeeded", fetch_run.status
    assert_equal "enrl_test_123", fetch_run.stats.fetch("resource_id")
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
    assert_equal "hmac-sha512", event.metadata.dig("signature_verification", "algorithm")
  ensure
    ENV.delete("VITABLE_WEBHOOK_SECRET")
  end

  test "rejects SHA256 webhook signatures when webhook secret is configured" do
    @connection.update!(webhook_secret_reference: "VITABLE_WEBHOOK_SECRET")
    ENV["VITABLE_WEBHOOK_SECRET"] = "whsec_test_value"
    payload = webhook_payload.merge(event_id: "wevt_test_sha256_signature")
    raw_body = payload.to_json
    timestamp = "2026-01-23T14:31:00+00:00"
    signature = OpenSSL::HMAC.hexdigest("SHA256", ENV.fetch("VITABLE_WEBHOOK_SECRET"), "#{timestamp}.#{raw_body}")

    assert_no_difference "WebhookEvent.count" do
      post api_v1_webhooks_vitable_path,
        params: payload,
        headers: signed_headers(timestamp:, signature:, algorithm: "sha256"),
        as: :json
    end

    assert_response :unauthorized
    response_payload = JSON.parse(response.body)
    assert_equal "signature_invalid", response_payload.fetch("signature")
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

  def signed_headers(timestamp:, signature:, algorithm: "sha512")
    {
      "CONTENT_TYPE" => "application/json",
      "X-Vitable-Timestamp" => timestamp,
      "X-Vitable-Signature" => "#{algorithm}=#{signature}"
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
