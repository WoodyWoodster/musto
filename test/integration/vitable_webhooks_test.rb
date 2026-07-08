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

  test "accepts a Vitable webhook that uses id for the event identifier" do
    payload = webhook_payload.except(:event_id).merge(id: "wevt_test_sdk_id_shape")

    assert_difference "WebhookEvent.count", 1 do
      post api_v1_webhooks_vitable_path, params: payload, as: :json
    end

    assert_response :accepted
    event = WebhookEvent.find_by!(event_id: "wevt_test_sdk_id_shape")
    assert_equal @connection, event.integration_connection
    assert_equal "wevt_test_sdk_id_shape", event.payload.fetch("event_id")
  end

  test "accepts a Vitable webhook that uses occurred_at for the event timestamp" do
    occurred_at = Time.current.change(usec: 0)
    payload = webhook_payload.except(:created_at).merge(
      event_id: "wevt_test_occurred_at_shape",
      occurred_at: occurred_at.iso8601
    )

    assert_difference "WebhookEvent.count", 1 do
      post api_v1_webhooks_vitable_path, params: payload, as: :json
    end

    assert_response :accepted
    event = WebhookEvent.find_by!(event_id: "wevt_test_occurred_at_shape")
    assert_equal occurred_at.to_i, event.occurred_at.to_i
    assert_equal occurred_at.iso8601, event.payload.fetch("created_at")
  end

  test "accepts a Vitable webhook that uses organization_external_id for routing" do
    payload = webhook_payload.except(:organization_id).merge(
      event_id: "wevt_test_external_org_shape",
      organization_external_id: @organization.external_id
    )

    assert_difference "WebhookEvent.count", 1 do
      post api_v1_webhooks_vitable_path, params: payload, as: :json
    end

    assert_response :accepted
    event = WebhookEvent.find_by!(event_id: "wevt_test_external_org_shape")
    assert_equal @connection, event.integration_connection
    assert_equal @organization.external_id, event.organization_external_id
    assert_equal @organization.external_id, event.payload.fetch("organization_id")
  end

  test "rejects a Vitable webhook with an invalid event timestamp" do
    payload = webhook_payload.merge(
      event_id: "wevt_test_invalid_timestamp",
      created_at: "not-a-timestamp"
    )

    assert_no_difference "WebhookEvent.count" do
      post api_v1_webhooks_vitable_path, params: payload, as: :json
    end

    assert_response :unprocessable_entity
    assert_includes JSON.parse(response.body).fetch("errors"), "Invalid Vitable webhook payload: created_at could not be parsed as ISO 8601"
  end

  test "rejects a Vitable webhook without an event identifier" do
    payload = webhook_payload.except(:event_id)

    assert_no_difference "WebhookEvent.count" do
      post api_v1_webhooks_vitable_path, params: payload, as: :json
    end

    assert_response :unprocessable_entity
    assert_includes JSON.parse(response.body).fetch("errors"), "Invalid Vitable webhook payload: key not found: :event_id"
  end

  test "does not duplicate webhook events with the same event id" do
    post api_v1_webhooks_vitable_path, params: webhook_payload, as: :json
    assert_response :accepted

    assert_no_difference "WebhookEvent.count" do
      post api_v1_webhooks_vitable_path, params: webhook_payload, as: :json
    end

    assert_response :accepted
  end

  test "unprocessed duplicate webhook deliveries refresh the latest payload before retry processing" do
    first_payload = webhook_payload.merge(
      event_id: "wevt_test_retry_refresh",
      resource_id: "enrl_stale"
    )
    first_result = Vitable::ProcessWebhookCommand.new(payload: first_payload).call

    assert first_result.success?
    event = WebhookEvent.find_by!(event_id: "wevt_test_retry_refresh")
    assert_equal "needs_credentials", event.status
    assert_equal "enrl_stale", event.resource_id

    ENV["VITABLE_CONNECT_API_KEY"] = "vit_apk_test_value"
    fetched_resource_ids = []
    gateway_class = Class.new do
      define_method(:initialize) { |_connection| }
      define_method(:fetch_resource) do |_resource_type, resource_id|
        fetched_resource_ids << resource_id
        {
          data: {
            id: resource_id,
            employee_id: "empl_current",
            benefit: {
              id: "bprd_current",
              name: "Primary Care"
            },
            status: "accepted"
          }
        }
      end
    end

    retry_payload = first_payload.merge(resource_id: "enrl_current")
    retry_result = Vitable::ProcessWebhookCommand.new(payload: retry_payload, gateway_class:).call

    assert retry_result.success?
    assert_equal [ "enrl_current" ], fetched_resource_ids
    assert_equal "processed", event.reload.status
    assert_equal "enrl_current", event.resource_id
    assert_equal "enrl_current", event.payload.fetch("resource_id")
  ensure
    ENV.delete("VITABLE_CONNECT_API_KEY")
  end

  test "direct resource fetches record missing credentials before gateway calls" do
    gateway_class = Class.new do
      define_method(:initialize) { |_connection| }
      define_method(:fetch_resource) { |_resource_type, _resource_id| raise "gateway should not be called without credentials" }
    end

    result = Vitable::FetchResourceCommand.new(
      dto: Vitable::FetchResourceDto.new(connection_id: @connection.id, resource_type: "employee", resource_id: "empl_missing_key"),
      gateway_class:
    ).call

    assert result.failure?
    sync_run = @connection.sync_runs.where(operation: "fetch", resource_type: "employee").recent_first.first
    assert_equal "needs_credentials", sync_run.status
    assert_match "VITABLE_CONNECT_API_KEY", sync_run.error_message
    assert_equal "VITABLE_CONNECT_API_KEY is not configured", sync_run.stats.fetch("blocked_reason")
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
            employee_id: "empl_snapshot_casey",
            benefit: {
              id: "bprd_snapshot_primary",
              name: "Primary Care"
            },
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

  test "matches fetched employee webhook resources by email case insensitively" do
    employer = @organization.employers.create!(name: "Webhook Email Match Employer", status: "active")
    employee = employer.employees.create!(
      first_name: "Riley",
      last_name: "Case",
      email: "Riley.CaseMatch@example.com"
    )
    ENV["VITABLE_CONNECT_API_KEY"] = "vit_apk_test_value"
    gateway_class = Class.new do
      define_method(:initialize) { |_connection| }
      define_method(:fetch_resource) do |_resource_type, resource_id|
        {
          data: {
            id: resource_id,
            email: "riley.casematch@example.com",
            status: "active",
            member_id: "mem_remote_riley_case"
          }
        }
      end
    end

    result = Vitable::ProcessWebhookCommand.new(
      payload: webhook_payload.merge(
        event_id: "wevt_test_employee_email_case_match",
        event_name: "employee.eligibility_granted",
        resource_type: "employee",
        resource_id: "empl_remote_riley_case"
      ),
      gateway_class:
    ).call

    assert result.success?
    event = WebhookEvent.find_by!(event_id: "wevt_test_employee_email_case_match")
    reconciliation = event.metadata.fetch("resource_reconciliation")

    assert_equal "processed", event.status
    assert_equal "matched", reconciliation.fetch("status")
    assert_equal "email", reconciliation.fetch("matched_by")
    assert_equal employee.id, reconciliation.fetch("local_record_id")
    assert_equal "empl_remote_riley_case", employee.reload.vitable_id
    assert_equal "mem_remote_riley_case", employee.metadata.fetch("vitable_member_id")
  ensure
    ENV.delete("VITABLE_CONNECT_API_KEY")
  end

  test "fails fetched employee webhook reconciliation when response omits remote resource id" do
    employer = @organization.employers.create!(name: "Webhook Employer", status: "active")
    employee = employer.employees.create!(first_name: "Casey", last_name: "Nguyen", email: "casey@example.com")
    ENV["VITABLE_CONNECT_API_KEY"] = "vit_apk_test_value"
    gateway_class = Class.new do
      define_method(:initialize) { |_connection| }
      define_method(:fetch_resource) do |_resource_type, _resource_id|
        {
          data: {
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
        event_id: "wevt_test_employee_missing_resource_id",
        event_name: "employee.eligibility_granted",
        resource_type: "employee",
        resource_id: "empl_remote_casey"
      ),
      gateway_class:
    ).call

    assert result.failure?
    event = WebhookEvent.find_by!(event_id: "wevt_test_employee_missing_resource_id")

    assert_equal "failed", event.status
    assert_match "remote resource ID", event.error_message
    assert_match "remote resource ID", result.errors.to_sentence
    assert_nil employee.reload.vitable_id
    assert_nil employee.metadata.fetch("vitable_member_id", nil)
  ensure
    ENV.delete("VITABLE_CONNECT_API_KEY")
  end

  test "fails fetched employee webhook reconciliation when response omits member id" do
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
            status: "active"
          }
        }
      end
    end

    result = Vitable::ProcessWebhookCommand.new(
      payload: webhook_payload.merge(
        event_id: "wevt_test_employee_missing_member_id",
        event_name: "employee.eligibility_granted",
        resource_type: "employee",
        resource_id: "empl_remote_casey"
      ),
      gateway_class:
    ).call

    assert result.failure?
    event = WebhookEvent.find_by!(event_id: "wevt_test_employee_missing_member_id")
    sync_run = @connection.sync_runs.where(operation: "fetch", resource_type: "employee").recent_first.first

    assert_equal "failed", event.status
    assert_match "remote member ID", event.error_message
    assert_match "remote member ID", result.errors.to_sentence
    assert_equal "failed", sync_run.status
    assert_match "remote member ID", sync_run.error_message
    assert_equal "ArgumentError", sync_run.stats.fetch("error_class")
    assert_equal "empl_remote_casey", sync_run.stats.dig("remote_response", "data", "id")
    assert_nil employee.reload.vitable_id
    assert_nil employee.metadata.fetch("vitable_member_id", nil)
  ensure
    ENV.delete("VITABLE_CONNECT_API_KEY")
  end

  test "reconciles payroll deduction payload-only webhooks without remote fetch" do
    employer = @organization.employers.create!(name: "Payroll Deduction Employer", status: "active")
    employee = employer.employees.create!(
      first_name: "Casey",
      last_name: "Deductions",
      email: "casey.payload@example.com",
      vitable_id: "empl_payload_casey"
    )
    plan = employer.benefit_plans.create!(
      name: "Primary Care",
      carrier: "Vitable",
      category: "direct_primary_care",
      monthly_premium_cents: 9_900,
      vitable_id: "plan_payload_primary"
    )
    enrollment = employee.enrollments.create!(
      benefit_plan: plan,
      status: "accepted",
      effective_on: Date.current,
      vitable_id: "enrl_payload_primary"
    )
    ENV["VITABLE_CONNECT_API_KEY"] = "vit_apk_test_value"
    gateway_class = Class.new do
      def self.retrievable_resource_type?(_resource_type)
        false
      end

      def self.webhook_resource_type?(resource_type)
        resource_type == "payroll_deduction"
      end

      def self.payload_only_webhook_resource_type?(resource_type)
        resource_type == "payroll_deduction"
      end

      define_method(:initialize) { |_connection| }
      define_method(:fetch_resource) { |_resource_type, _resource_id| raise "gateway should not fetch payload-only resources" }
    end

    assert_no_difference -> { @connection.sync_runs.count } do
      result = Vitable::ProcessWebhookCommand.new(
        payload: webhook_payload.merge(
          event_id: "wevt_test_payroll_deduction_payload_only",
          event_name: "employee.deduction_created",
          resource_type: "payroll_deduction",
          resource_id: "pded_remote_payload",
          data: {
            employee_id: "empl_payload_casey",
            plan_id: "plan_payload_primary",
            enrollment_id: "enrl_payload_primary",
            benefit_name: "Primary Care",
            deduction_amount_in_cents: 7_900,
            frequency: "bi_weekly",
            status: "active"
          }
        ),
        gateway_class:
      ).call

      assert result.success?
      assert_equal "payload_only", result.value
    end

    event = WebhookEvent.find_by!(event_id: "wevt_test_payroll_deduction_payload_only")
    reconciliation = event.metadata.fetch("resource_reconciliation")
    deduction = employer.payroll_runs.sole.payroll_deductions.sole

    assert_equal "processed", event.status
    assert_not_nil event.processed_at
    assert_equal "matched", reconciliation.fetch("status")
    assert_equal "payroll_deduction", reconciliation.fetch("resource_type")
    assert_equal employee.id, reconciliation.fetch("local_record_id")
    assert_equal "remote_employee_id", reconciliation.fetch("matched_by")
    assert_equal enrollment.id, deduction.enrollment_id
    assert_equal "pded_remote_payload", deduction.vitable_id
    assert_equal 7_900, deduction.amount_cents
    assert_equal "ready", deduction.status
    assert_equal "VITABLE_PRIMARY_CARE", deduction.code
    assert_equal "vitable_webhook_payload", deduction.metadata.fetch("source")
    assert_equal "wevt_test_payroll_deduction_payload_only", deduction.metadata.fetch("last_webhook_event_id")
    assert_includes reconciliation.fetch("applied_changes"), "payroll_deductions.#{deduction.id}"
    assert_nil event.metadata.fetch("resource_snapshot", nil)
  ensure
    ENV.delete("VITABLE_CONNECT_API_KEY")
  end

  test "matches payroll deduction payload-only webhooks by employee email case insensitively" do
    employer = @organization.employers.create!(name: "Payroll Email Match Employer", status: "active")
    employee = employer.employees.create!(
      first_name: "Taylor",
      last_name: "Deductions",
      email: "Taylor.DeductionMatch@example.com"
    )
    plan = employer.benefit_plans.create!(
      name: "Primary Care",
      carrier: "Vitable",
      category: "direct_primary_care",
      monthly_premium_cents: 9_900,
      vitable_id: "plan_email_primary"
    )
    enrollment = employee.enrollments.create!(
      benefit_plan: plan,
      status: "accepted",
      effective_on: Date.current,
      vitable_id: "enrl_email_primary"
    )
    ENV["VITABLE_CONNECT_API_KEY"] = "vit_apk_test_value"
    gateway_class = Class.new do
      def self.retrievable_resource_type?(_resource_type)
        false
      end

      def self.webhook_resource_type?(resource_type)
        resource_type == "payroll_deduction"
      end

      def self.payload_only_webhook_resource_type?(resource_type)
        resource_type == "payroll_deduction"
      end

      define_method(:initialize) { |_connection| }
      define_method(:fetch_resource) { |_resource_type, _resource_id| raise "gateway should not fetch payload-only resources" }
    end

    result = Vitable::ProcessWebhookCommand.new(
      payload: webhook_payload.merge(
        event_id: "wevt_test_payroll_deduction_email_case_match",
        event_name: "employee.deduction_created",
        resource_type: "payroll_deduction",
        resource_id: "pded_remote_email_case",
        data: {
          email: "taylor.deductionmatch@example.com",
          plan_id: "plan_email_primary",
          enrollment_id: "enrl_email_primary",
          benefit_name: "Primary Care",
          deduction_amount_in_cents: 7_900,
          frequency: "bi_weekly",
          status: "active"
        }
      ),
      gateway_class:
    ).call

    assert result.success?
    event = WebhookEvent.find_by!(event_id: "wevt_test_payroll_deduction_email_case_match")
    reconciliation = event.metadata.fetch("resource_reconciliation")
    deduction = employer.payroll_runs.sole.payroll_deductions.sole

    assert_equal "processed", event.status
    assert_equal "matched", reconciliation.fetch("status")
    assert_equal "email", reconciliation.fetch("matched_by")
    assert_equal employee.id, reconciliation.fetch("local_record_id")
    assert_equal enrollment.id, deduction.enrollment_id
    assert_equal "pded_remote_email_case", deduction.vitable_id
    assert_equal 7_900, deduction.amount_cents
  ensure
    ENV.delete("VITABLE_CONNECT_API_KEY")
  end

  test "reconciles dependent payload-only webhooks without remote fetch" do
    employer = @organization.employers.create!(name: "Dependent Payload Employer", status: "active")
    employee = employer.employees.create!(
      first_name: "Casey",
      last_name: "Dependents",
      email: "casey.dependents@example.com",
      vitable_id: "empl_dependent_casey"
    )
    ENV["VITABLE_CONNECT_API_KEY"] = "vit_apk_test_value"
    gateway_class = Class.new do
      def self.retrievable_resource_type?(_resource_type)
        false
      end

      def self.webhook_resource_type?(resource_type)
        resource_type == "dependent"
      end

      def self.payload_only_webhook_resource_type?(resource_type)
        resource_type == "dependent"
      end

      define_method(:initialize) { |_connection| }
      define_method(:fetch_resource) { |_resource_type, _resource_id| raise "gateway should not fetch payload-only resources" }
    end

    assert_no_difference -> { @connection.sync_runs.count } do
      result = Vitable::ProcessWebhookCommand.new(
        payload: webhook_payload.merge(
          event_id: "wevt_test_dependent_payload_only",
          event_name: "dependent.updated",
          resource_type: "dependent",
          resource_id: "dep_remote_payload",
          data: {
            employee_id: "empl_dependent_casey",
            first_name: "Harper",
            last_name: "Dependents",
            relationship: "child",
            date_of_birth: "2018-03-04",
            status: "active"
          }
        ),
        gateway_class:
      ).call

      assert result.success?
      assert_equal "payload_only", result.value
    end

    event = WebhookEvent.find_by!(event_id: "wevt_test_dependent_payload_only")
    reconciliation = event.metadata.fetch("resource_reconciliation")
    dependent = employee.dependents.sole

    assert_equal "processed", event.status
    assert_equal "matched", reconciliation.fetch("status")
    assert_equal "dependent", reconciliation.fetch("resource_type")
    assert_equal "created_from_payload", reconciliation.fetch("matched_by")
    assert_equal dependent.id, reconciliation.fetch("local_record_id")
    assert_equal "dep_remote_payload", dependent.vitable_id
    assert_equal "Harper", dependent.first_name
    assert_equal "child", dependent.relationship
    assert_equal Date.new(2018, 3, 4), dependent.date_of_birth
    assert_equal "enrolled", dependent.enrollment_status
    assert_equal "eligible", dependent.eligibility_status
    assert_equal "wevt_test_dependent_payload_only", dependent.metadata.fetch("vitable_last_webhook_event_id")
    assert_includes reconciliation.fetch("applied_changes"), "dependents.created"
  ensure
    ENV.delete("VITABLE_CONNECT_API_KEY")
  end

  test "matches dependent payload-only webhooks by employee email case insensitively" do
    employer = @organization.employers.create!(name: "Dependent Email Match Employer", status: "active")
    employee = employer.employees.create!(
      first_name: "Jordan",
      last_name: "Dependents",
      email: "Jordan.DependentMatch@example.com"
    )
    ENV["VITABLE_CONNECT_API_KEY"] = "vit_apk_test_value"
    gateway_class = Class.new do
      def self.retrievable_resource_type?(_resource_type)
        false
      end

      def self.webhook_resource_type?(resource_type)
        resource_type == "dependent"
      end

      def self.payload_only_webhook_resource_type?(resource_type)
        resource_type == "dependent"
      end

      define_method(:initialize) { |_connection| }
      define_method(:fetch_resource) { |_resource_type, _resource_id| raise "gateway should not fetch payload-only resources" }
    end

    result = Vitable::ProcessWebhookCommand.new(
      payload: webhook_payload.merge(
        event_id: "wevt_test_dependent_email_case_match",
        event_name: "dependent.updated",
        resource_type: "dependent",
        resource_id: "dep_remote_email_case",
        data: {
          employee_email: "jordan.dependentmatch@example.com",
          first_name: "Avery",
          last_name: "Dependents",
          relationship: "child",
          date_of_birth: "2020-09-10",
          status: "active"
        }
      ),
      gateway_class:
    ).call

    assert result.success?
    event = WebhookEvent.find_by!(event_id: "wevt_test_dependent_email_case_match")
    reconciliation = event.metadata.fetch("resource_reconciliation")
    dependent = employee.dependents.sole

    assert_equal "processed", event.status
    assert_equal "matched", reconciliation.fetch("status")
    assert_equal "created_from_payload", reconciliation.fetch("matched_by")
    assert_equal dependent.id, reconciliation.fetch("local_record_id")
    assert_equal employee.id, dependent.employee_id
    assert_equal "dep_remote_email_case", dependent.vitable_id
    assert_equal "Avery", dependent.first_name
    assert_equal "eligible", dependent.eligibility_status
  ensure
    ENV.delete("VITABLE_CONNECT_API_KEY")
  end

  test "reconciles plan year payload-only webhooks without remote fetch" do
    employer = @organization.employers.create!(
      name: "Plan Year Employer",
      status: "active",
      vitable_id: "empr_plan_year_payload"
    )
    plan = employer.benefit_plans.create!(
      name: "Minimum Essential Coverage",
      carrier: "Vitable",
      category: "minimum_essential_coverage",
      monthly_premium_cents: 14_900,
      plan_year: 2027
    )
    campaign = employer.open_enrollment_campaigns.create!(
      name: "2027 Open Enrollment",
      plan_year: 2027,
      starts_on: Date.new(2026, 11, 1),
      ends_on: Date.new(2026, 11, 15),
      status: "draft"
    )
    ENV["VITABLE_CONNECT_API_KEY"] = "vit_apk_test_value"
    gateway_class = Class.new do
      def self.retrievable_resource_type?(_resource_type)
        false
      end

      def self.webhook_resource_type?(resource_type)
        resource_type == "plan_year"
      end

      def self.payload_only_webhook_resource_type?(resource_type)
        resource_type == "plan_year"
      end

      define_method(:initialize) { |_connection| }
      define_method(:fetch_resource) { |_resource_type, _resource_id| raise "gateway should not fetch payload-only resources" }
    end

    assert_no_difference -> { @connection.sync_runs.count } do
      result = Vitable::ProcessWebhookCommand.new(
        payload: webhook_payload.merge(
          event_id: "wevt_test_plan_year_payload_only",
          event_name: "plan_year.updated",
          resource_type: "plan_year",
          resource_id: "pyear_remote_payload",
          data: {
            employer_id: "empr_plan_year_payload",
            year: 2027,
            starts_on: "2027-01-01",
            ends_on: "2027-12-31",
            open_enrollment_starts_on: "2026-10-15",
            open_enrollment_ends_on: "2026-11-05",
            status: "active"
          }
        ),
        gateway_class:
      ).call

      assert result.success?
      assert_equal "payload_only", result.value
    end

    event = WebhookEvent.find_by!(event_id: "wevt_test_plan_year_payload_only")
    reconciliation = event.metadata.fetch("resource_reconciliation")
    snapshot = employer.reload.settings.dig("vitable_plan_year_snapshots", "pyear_remote_payload")

    assert_equal "processed", event.status
    assert_equal "matched", reconciliation.fetch("status")
    assert_equal "plan_year", reconciliation.fetch("resource_type")
    assert_equal "Employer", reconciliation.fetch("local_record_type")
    assert_equal employer.id, reconciliation.fetch("local_record_id")
    assert_equal "remote_employer_id", reconciliation.fetch("matched_by")
    assert_equal 2027, snapshot.fetch("plan_year")
    assert_equal "wevt_test_plan_year_payload_only", snapshot.fetch("last_webhook_event_id")
    assert_equal Date.new(2027, 1, 1), plan.reload.effective_on
    assert_equal Date.new(2027, 12, 31), plan.expires_on
    assert_equal "pyear_remote_payload", plan.metadata.fetch("vitable_plan_year_id")
    assert_equal "wevt_test_plan_year_payload_only", plan.metadata.fetch("vitable_plan_year_last_webhook_event_id")
    assert_equal Date.new(2026, 10, 15), campaign.reload.starts_on
    assert_equal Date.new(2026, 11, 5), campaign.ends_on
    assert_equal "active", campaign.status
    assert_equal "pyear_remote_payload", campaign.metadata.fetch("vitable_plan_year_id")
    assert_includes reconciliation.fetch("applied_changes"), "employer.settings.vitable_plan_year_snapshots"
    assert_includes reconciliation.fetch("applied_changes"), "benefit_plans.#{plan.id}"
    assert_includes reconciliation.fetch("applied_changes"), "open_enrollment_campaigns.#{campaign.id}"
    assert_empty reconciliation.fetch("warnings")
    assert_nil event.metadata.fetch("resource_snapshot", nil)
  ensure
    ENV.delete("VITABLE_CONNECT_API_KEY")
  end

  test "stores unknown unsupported Vitable webhook resource types with explicit diagnostics" do
    ENV["VITABLE_CONNECT_API_KEY"] = "vit_apk_test_value"
    gateway_class = Class.new do
      def self.retrievable_resource_type?(_resource_type)
        false
      end

      def self.webhook_resource_type?(_resource_type)
        false
      end

      def self.payload_only_webhook_resource_type?(_resource_type)
        false
      end

      define_method(:initialize) { |_connection| }
      define_method(:fetch_resource) { |_resource_type, _resource_id| raise "gateway should not fetch unknown resources" }
    end

    result = Vitable::ProcessWebhookCommand.new(
      payload: webhook_payload.merge(
        event_id: "wevt_test_unknown_resource_snapshot_only",
        event_name: "benefit_plan.updated",
        resource_type: "benefit_plan",
        resource_id: "bpln_remote_snapshot_only"
      ),
      gateway_class:
    ).call

    assert result.success?
    assert_equal "snapshot_only", result.value
    event = WebhookEvent.find_by!(event_id: "wevt_test_unknown_resource_snapshot_only")
    reconciliation = event.metadata.fetch("resource_reconciliation")

    assert_equal "processed", event.status
    assert_equal "skipped", reconciliation.fetch("status")
    assert_equal "benefit_plan", reconciliation.fetch("resource_type")
    assert_match "does not list it as a filterable webhook resource type", reconciliation.fetch("warnings").join(" ")
  ensure
    ENV.delete("VITABLE_CONNECT_API_KEY")
  end

  test "direct resource fetches reconcile fetched employee state" do
    employer = @organization.employers.create!(name: "Direct Fetch Employer", status: "active")
    employee = employer.employees.create!(first_name: "Drew", last_name: "Miller", email: "drew.fetch@example.com", employment_status: "terminated")
    ENV["VITABLE_CONNECT_API_KEY"] = "vit_apk_test_value"
    gateway_class = Class.new do
      define_method(:initialize) { |_connection| }
      define_method(:fetch_resource) do |_resource_type, resource_id|
        {
          data: {
            id: resource_id,
            reference_id: "musto_employee_#{Employee.find_by!(email: "drew.fetch@example.com").id}",
            email: "drew.fetch@example.com",
            status: "active",
            member_id: "mem_direct_drew"
          }
        }
      end
    end

    result = Vitable::FetchResourceCommand.new(
      dto: Vitable::FetchResourceDto.new(connection_id: @connection.id, resource_type: "employee", resource_id: "empl_direct_drew"),
      gateway_class:
    ).call

    assert result.success?
    employee.reload
    sync_run = @connection.sync_runs.where(operation: "fetch", resource_type: "employee").recent_first.first

    assert_equal "empl_direct_drew", employee.vitable_id
    assert_equal "active", employee.employment_status
    assert_equal "active", employee.metadata.fetch("vitable_remote_status")
    assert_equal "mem_direct_drew", employee.metadata.fetch("vitable_member_id")
    assert_equal "matched", sync_run.stats.dig("resource_reconciliation", "status")
    assert_equal "Employee", sync_run.stats.dig("resource_reconciliation", "local_record_type")
    assert_equal employee.id, sync_run.stats.dig("resource_reconciliation", "local_record_id")
    assert_equal "reference_id", sync_run.stats.dig("resource_reconciliation", "matched_by")
  ensure
    ENV.delete("VITABLE_CONNECT_API_KEY")
  end

  test "direct resource fetch fails when response id differs from requested resource id" do
    employer = @organization.employers.create!(name: "Direct Fetch Employer", status: "active")
    employee = employer.employees.create!(first_name: "Drew", last_name: "Miller", email: "drew.fetch@example.com")
    ENV["VITABLE_CONNECT_API_KEY"] = "vit_apk_test_value"
    gateway_class = Class.new do
      define_method(:initialize) { |_connection| }
      define_method(:fetch_resource) do |_resource_type, _resource_id|
        {
          data: {
            id: "empl_wrong_drew",
            reference_id: "musto_employee_#{Employee.find_by!(email: "drew.fetch@example.com").id}",
            email: "drew.fetch@example.com",
            status: "active",
            member_id: "mem_direct_drew"
          }
        }
      end
    end

    result = Vitable::FetchResourceCommand.new(
      dto: Vitable::FetchResourceDto.new(connection_id: @connection.id, resource_type: "employee", resource_id: "empl_direct_drew"),
      gateway_class:
    ).call

    assert result.failure?
    sync_run = @connection.sync_runs.where(operation: "fetch", resource_type: "employee").recent_first.first

    assert_equal "failed", sync_run.status
    assert_match "expected empl_direct_drew", sync_run.error_message
    assert_equal "ArgumentError", sync_run.stats.fetch("error_class")
    assert_equal "empl_wrong_drew", sync_run.stats.dig("remote_response", "data", "id")
    assert_equal "mem_direct_drew", sync_run.stats.dig("remote_response", "data", "member_id")
    assert_match "expected empl_direct_drew", result.errors.to_sentence
    assert_nil employee.reload.vitable_id
    assert_nil employee.metadata.fetch("vitable_member_id", nil)
  ensure
    ENV.delete("VITABLE_CONNECT_API_KEY")
  end

  test "direct resource fetch fails when response omits resource attributes" do
    ENV["VITABLE_CONNECT_API_KEY"] = "vit_apk_test_value"
    gateway_class = Class.new do
      define_method(:initialize) { |_connection| }
      define_method(:fetch_resource) { |_resource_type, _resource_id| { data: {} } }
    end

    result = Vitable::FetchResourceCommand.new(
      dto: Vitable::FetchResourceDto.new(connection_id: @connection.id, resource_type: "employee", resource_id: "empl_direct_missing_attrs"),
      gateway_class:
    ).call

    assert result.failure?
    sync_run = @connection.sync_runs.where(operation: "fetch", resource_type: "employee").recent_first.first

    assert_equal "failed", sync_run.status
    assert_match "resource attributes", sync_run.error_message
    assert_equal "ArgumentError", sync_run.stats.fetch("error_class")
    assert_equal({}, sync_run.stats.dig("remote_response", "data"))
    assert_match "resource attributes", result.errors.to_sentence
  ensure
    ENV.delete("VITABLE_CONNECT_API_KEY")
  end

  test "direct resource fetch fails when retrieve response returns a data array" do
    ENV["VITABLE_CONNECT_API_KEY"] = "vit_apk_test_value"
    gateway_class = Class.new do
      define_method(:initialize) { |_connection| }
      define_method(:fetch_resource) do |_resource_type, resource_id|
        {
          data: [
            {
              id: resource_id,
              reference_id: "musto_employee_999",
              email: "array-response@example.com",
              status: "active",
              member_id: "mem_array_response"
            }
          ]
        }
      end
    end

    result = Vitable::FetchResourceCommand.new(
      dto: Vitable::FetchResourceDto.new(connection_id: @connection.id, resource_type: "employee", resource_id: "empl_direct_array"),
      gateway_class:
    ).call

    assert result.failure?
    sync_run = @connection.sync_runs.where(operation: "fetch", resource_type: "employee").recent_first.first

    assert_equal "failed", sync_run.status
    assert_match "data array", sync_run.error_message
    assert_equal "ArgumentError", sync_run.stats.fetch("error_class")
    assert_equal "empl_direct_array", sync_run.stats.dig("remote_response", "data", 0, "id")
    assert_match "single resource object", result.errors.to_sentence
  ensure
    ENV.delete("VITABLE_CONNECT_API_KEY")
  end

  test "employee deactivated webhooks terminate the local HRIS employee" do
    employer = @organization.employers.create!(name: "Deactivation Employer", status: "active")
    employee = employer.employees.create!(first_name: "Dana", last_name: "Inactive", email: "dana.inactive@example.com")
    plan = employer.benefit_plans.create!(name: "Vitable Care", category: "direct_primary_care", carrier: "Vitable")
    enrollment = employee.enrollments.create!(benefit_plan: plan, status: "accepted", accepted_at: 1.month.ago)
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
      amount_cents: 9900,
      status: "ready"
    )
    ENV["VITABLE_CONNECT_API_KEY"] = "vit_apk_test_value"
    gateway_class = Class.new do
      define_method(:initialize) { |_connection| }
      define_method(:fetch_resource) do |_resource_type, resource_id|
        {
          data: {
            id: resource_id,
            reference_id: "musto_employee_#{Employee.find_by!(email: "dana.inactive@example.com").id}",
            email: "dana.inactive@example.com",
            status: "inactive",
            member_id: "mem_deactivated_dana"
          }
        }
      end
    end

    result = Vitable::ProcessWebhookCommand.new(
      payload: webhook_payload.merge(
        event_id: "wevt_test_employee_deactivated",
        event_name: "employee.deactivated",
        resource_type: "employee",
        resource_id: "empl_deactivated_dana"
      ),
      gateway_class:
    ).call

    assert result.success?
    employee.reload
    reconciliation = WebhookEvent.find_by!(event_id: "wevt_test_employee_deactivated").metadata.fetch("resource_reconciliation")

    assert_equal "empl_deactivated_dana", employee.vitable_id
    assert_equal "terminated", employee.employment_status
    assert_equal "inactive", employee.metadata.fetch("vitable_remote_status")
    assert_equal "deactivated", employee.metadata.fetch("vitable_lifecycle_status")
    assert_equal "inactive", enrollment.reload.status
    assert_nil enrollment.accepted_at
    assert_equal "inactive", enrollment.metadata.fetch("vitable_lifecycle_status")
    assert_equal 0, deduction.reload.amount_cents
    assert_equal "inactive", deduction.status
    assert_includes reconciliation.fetch("applied_changes"), "employment_status"
    assert_includes reconciliation.fetch("applied_changes"), "enrollments.#{enrollment.id}"
    assert_includes reconciliation.fetch("applied_changes"), "payroll_deductions.#{deduction.id}"
  ensure
    ENV.delete("VITABLE_CONNECT_API_KEY")
  end

  test "employee eligibility terminated webhooks deactivate benefits without terminating HRIS employee" do
    employer = @organization.employers.create!(name: "Eligibility Employer", status: "active")
    employee = employer.employees.create!(first_name: "Elliot", last_name: "Eligible", email: "elliot.eligible@example.com")
    plan = employer.benefit_plans.create!(name: "Vitable Care", category: "direct_primary_care", carrier: "Vitable")
    enrollment = employee.enrollments.create!(benefit_plan: plan, status: "accepted", accepted_at: 1.month.ago)
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
      amount_cents: 9900,
      status: "ready"
    )
    ENV["VITABLE_CONNECT_API_KEY"] = "vit_apk_test_value"
    gateway_class = Class.new do
      define_method(:initialize) { |_connection| }
      define_method(:fetch_resource) do |_resource_type, resource_id|
        {
          data: {
            id: resource_id,
            reference_id: "musto_employee_#{Employee.find_by!(email: "elliot.eligible@example.com").id}",
            email: "elliot.eligible@example.com",
            status: "active",
            member_id: "mem_eligibility_elliot"
          }
        }
      end
    end

    result = Vitable::ProcessWebhookCommand.new(
      payload: webhook_payload.merge(
        event_id: "wevt_test_employee_eligibility_terminated",
        event_name: "employee.eligibility_terminated",
        resource_type: "employee",
        resource_id: "empl_eligibility_elliot"
      ),
      gateway_class:
    ).call

    assert result.success?
    employee.reload
    reconciliation = WebhookEvent.find_by!(event_id: "wevt_test_employee_eligibility_terminated").metadata.fetch("resource_reconciliation")

    assert_equal "active", employee.employment_status
    assert_equal "terminated", employee.metadata.fetch("vitable_eligibility_status")
    assert_equal "inactive", enrollment.reload.status
    assert_nil enrollment.accepted_at
    assert_equal "employee.eligibility_terminated", enrollment.metadata.fetch("vitable_lifecycle_event_name")
    assert_equal 0, deduction.reload.amount_cents
    assert_equal "inactive", deduction.status
    assert_equal "employee.eligibility_terminated", deduction.metadata.fetch("last_webhook_event_name")
    assert_not_includes reconciliation.fetch("applied_changes"), "employment_status"
    assert_includes reconciliation.fetch("applied_changes"), "enrollments.#{enrollment.id}"
    assert_includes reconciliation.fetch("applied_changes"), "payroll_deductions.#{deduction.id}"
  ensure
    ENV.delete("VITABLE_CONNECT_API_KEY")
  end

  test "direct webhook event fetches import the remote event ledger row" do
    ENV["VITABLE_CONNECT_API_KEY"] = "vit_apk_test_value"
    occurred_at = Time.current.change(usec: 0)
    gateway_class = Class.new do
      define_method(:initialize) { |_connection| }
      define_method(:fetch_resource) do |_resource_type, resource_id|
        {
          data: {
            id: resource_id,
            organization_id: "org_webhook_test",
            event_name: "group.updated",
            resource_type: "group",
            resource_id: "grp_remote_imported",
            created_at: occurred_at.iso8601
          }
        }
      end
    end

    assert_difference "WebhookEvent.count", 1 do
      result = Vitable::FetchResourceCommand.new(
        dto: Vitable::FetchResourceDto.new(connection_id: @connection.id, resource_type: "webhook_event", resource_id: "wevt_remote_imported"),
        gateway_class:
      ).call

      assert result.success?
    end

    event = WebhookEvent.find_by!(event_id: "wevt_remote_imported")
    sync_run = @connection.sync_runs.where(operation: "fetch", resource_type: "webhook_event").recent_first.first

    assert_equal @connection.id, event.integration_connection_id
    assert_equal "group.updated", event.event_name
    assert_equal "group", event.resource_type
    assert_equal "grp_remote_imported", event.resource_id
    assert_equal occurred_at.to_i, event.occurred_at.to_i
    assert_equal "received", event.status
    assert_equal "vitable_resource_fetch", event.metadata.dig("remote_webhook_event_snapshot", "source")
    assert_equal "matched", sync_run.stats.dig("resource_reconciliation", "status")
    assert_equal "WebhookEvent", sync_run.stats.dig("resource_reconciliation", "local_record_type")
    assert_equal event.id, sync_run.stats.dig("resource_reconciliation", "local_record_id")
    assert_equal "created_from_event_id", sync_run.stats.dig("resource_reconciliation", "matched_by")
  ensure
    ENV.delete("VITABLE_CONNECT_API_KEY")
  end

  test "direct webhook event fetch accepts organization external id" do
    ENV["VITABLE_CONNECT_API_KEY"] = "vit_apk_test_value"
    occurred_at = Time.current.change(usec: 0)
    gateway_class = Class.new do
      define_method(:initialize) { |_connection| }
      define_method(:fetch_resource) do |_resource_type, resource_id|
        {
          data: {
            id: resource_id,
            organization_external_id: "org_webhook_test",
            event_name: "group.updated",
            resource_type: "group",
            resource_id: "grp_remote_external_org",
            created_at: occurred_at.iso8601
          }
        }
      end
    end

    assert_difference "WebhookEvent.count", 1 do
      result = Vitable::FetchResourceCommand.new(
        dto: Vitable::FetchResourceDto.new(connection_id: @connection.id, resource_type: "webhook_event", resource_id: "wevt_remote_external_org_fetch"),
        gateway_class:
      ).call

      assert result.success?
    end

    event = WebhookEvent.find_by!(event_id: "wevt_remote_external_org_fetch")
    sync_run = @connection.sync_runs.where(operation: "fetch", resource_type: "webhook_event").recent_first.first

    assert_equal @organization.external_id, event.organization_external_id
    assert_equal "grp_remote_external_org", event.resource_id
    assert_equal occurred_at.to_i, event.occurred_at.to_i
    assert_equal "matched", sync_run.stats.dig("resource_reconciliation", "status")
    assert_equal event.id, sync_run.stats.dig("resource_reconciliation", "local_record_id")
  ensure
    ENV.delete("VITABLE_CONNECT_API_KEY")
  end

  test "direct webhook event fetch fails when response id differs from requested event id" do
    ENV["VITABLE_CONNECT_API_KEY"] = "vit_apk_test_value"
    gateway_class = Class.new do
      define_method(:initialize) { |_connection| }
      define_method(:fetch_resource) do |_resource_type, _resource_id|
        {
          data: {
            id: "wevt_wrong_import",
            organization_id: "org_webhook_test",
            event_name: "group.updated",
            resource_type: "group",
            resource_id: "grp_remote_imported",
            created_at: Time.current.iso8601
          }
        }
      end
    end

    result = Vitable::FetchResourceCommand.new(
      dto: Vitable::FetchResourceDto.new(connection_id: @connection.id, resource_type: "webhook_event", resource_id: "wevt_remote_imported"),
      gateway_class:
    ).call

    assert result.failure?
    sync_run = @connection.sync_runs.where(operation: "fetch", resource_type: "webhook_event").recent_first.first

    assert_equal "failed", sync_run.status
    assert_match "expected wevt_remote_imported", sync_run.error_message
    assert_match "expected wevt_remote_imported", result.errors.to_sentence
    assert_nil WebhookEvent.find_by(event_id: "wevt_wrong_import")
    assert_nil WebhookEvent.find_by(event_id: "wevt_remote_imported")
  ensure
    ENV.delete("VITABLE_CONNECT_API_KEY")
  end

  test "direct webhook event fetches skip events for another organization" do
    ENV["VITABLE_CONNECT_API_KEY"] = "vit_apk_test_value"
    gateway_class = Class.new do
      define_method(:initialize) { |_connection| }
      define_method(:fetch_resource) do |_resource_type, resource_id|
        {
          data: {
            id: resource_id,
            organization_id: "org_other_vitable",
            event_name: "group.updated",
            resource_type: "group",
            resource_id: "grp_other",
            created_at: Time.current.iso8601
          }
        }
      end
    end

    assert_no_difference "WebhookEvent.count" do
      result = Vitable::FetchResourceCommand.new(
        dto: Vitable::FetchResourceDto.new(connection_id: @connection.id, resource_type: "webhook_event", resource_id: "wevt_other_org"),
        gateway_class:
      ).call

      assert result.success?
    end

    sync_run = @connection.sync_runs.where(operation: "fetch", resource_type: "webhook_event").recent_first.first
    warnings = sync_run.stats.dig("resource_reconciliation", "warnings")

    assert_equal "skipped", sync_run.stats.dig("resource_reconciliation", "status")
    assert_match "org_other_vitable", warnings.join(" ")
    assert_nil WebhookEvent.find_by(event_id: "wevt_other_org")
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
            member_id: "mem_deduction_casey",
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

  test "fails fetched enrollment webhook reconciliation when response omits employee id" do
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
    ENV["VITABLE_CONNECT_API_KEY"] = "vit_apk_test_value"
    gateway_class = Class.new do
      define_method(:initialize) { |_connection| }
      define_method(:fetch_resource) do |_resource_type, resource_id|
        {
          data: {
            id: resource_id,
            benefit: {
              id: "bprd_remote_care",
              name: "Vitable Care",
              category: "Medical",
              product_code: "VPC"
            },
            status: "enrolled",
            coverage_start: Date.current.beginning_of_month,
            employee_deduction_in_cents: 7900
          }
        }
      end
    end

    result = Vitable::ProcessWebhookCommand.new(
      payload: webhook_payload.merge(event_id: "wevt_test_enrollment_missing_employee_id"),
      gateway_class:
    ).call

    assert result.failure?
    event = WebhookEvent.find_by!(event_id: "wevt_test_enrollment_missing_employee_id")

    assert_equal "failed", event.status
    assert_match "remote employee ID", event.error_message
    assert_match "remote employee ID", result.errors.to_sentence
    assert_nil enrollment.reload.vitable_id
    assert_equal "pending", enrollment.status
  ensure
    ENV.delete("VITABLE_CONNECT_API_KEY")
  end

  test "creates payroll deductions from accepted enrollment resources" do
    employer = @organization.employers.create!(name: "Accepted Enrollment Employer", status: "active")
    employee = employer.employees.create!(
      first_name: "Avery",
      last_name: "Accepted",
      email: "avery.accepted@example.com",
      vitable_id: "empl_remote_avery"
    )
    plan = employer.benefit_plans.create!(
      name: "Vitable Primary Care",
      category: "direct_primary_care",
      carrier: "Vitable",
      vitable_id: "bprd_remote_primary"
    )
    enrollment = employee.enrollments.create!(benefit_plan: plan, status: "pending")
    answered_at = Time.current.change(usec: 0)
    coverage_start = Date.current.beginning_of_month
    ENV["VITABLE_CONNECT_API_KEY"] = "vit_apk_test_value"
    gateway_class = Class.new do
      define_method(:initialize) { |_connection| }
      define_method(:fetch_resource) do |_resource_type, resource_id|
        {
          data: {
            id: resource_id,
            employee_id: "empl_remote_avery",
            benefit: {
              id: "bprd_remote_primary",
              name: "Vitable Primary Care",
              category: "Medical",
              product_code: "VPC"
            },
            status: "enrolled",
            answered_at:,
            coverage_start:,
            employee_deduction_in_cents: 8400,
            employer_contribution_in_cents: 2100
          }
        }
      end
    end

    result = Vitable::ProcessWebhookCommand.new(
      payload: webhook_payload.merge(event_id: "wevt_test_enrollment_deduction_create"),
      gateway_class:
    ).call

    assert result.success?
    deduction = employer.payroll_runs.sole.payroll_deductions.sole
    reconciliation = WebhookEvent.find_by!(event_id: "wevt_test_enrollment_deduction_create").metadata.fetch("resource_reconciliation")

    assert_equal "accepted", enrollment.reload.status
    assert_equal enrollment.id, deduction.enrollment_id
    assert_equal employee.id, deduction.employee_id
    assert_equal "VITABLE_PRIMARY_CARE", deduction.code
    assert_equal 8400, deduction.amount_cents
    assert_equal "ready", deduction.status
    assert_equal "vitable_webhook_resource", deduction.metadata.fetch("source")
    assert_equal "enrollment.accepted", deduction.metadata.fetch("last_webhook_event_name")
    assert_includes reconciliation.fetch("applied_changes"), "payroll_deductions.#{deduction.id}"
  ensure
    ENV.delete("VITABLE_CONNECT_API_KEY")
  end

  test "uses enrollment event action for deduction sync when resource omits status" do
    employer = @organization.employers.create!(name: "Event Status Enrollment Employer", status: "active")
    employee = employer.employees.create!(
      first_name: "Morgan",
      last_name: "Eventstatus",
      email: "morgan.eventstatus@example.com",
      vitable_id: "empl_remote_morgan"
    )
    plan = employer.benefit_plans.create!(
      name: "Vitable Event Care",
      category: "direct_primary_care",
      carrier: "Vitable",
      vitable_id: "bprd_remote_event_care"
    )
    enrollment = employee.enrollments.create!(benefit_plan: plan, status: "pending")
    ENV["VITABLE_CONNECT_API_KEY"] = "vit_apk_test_value"
    gateway_class = Class.new do
      define_method(:initialize) { |_connection| }
      define_method(:fetch_resource) do |_resource_type, resource_id|
        {
          data: {
            id: resource_id,
            employee_id: "empl_remote_morgan",
            benefit: {
              id: "bprd_remote_event_care",
              name: "Vitable Event Care"
            },
            employee_deduction_in_cents: 8_100
          }
        }
      end
    end

    result = Vitable::ProcessWebhookCommand.new(
      payload: webhook_payload.merge(
        event_id: "wevt_test_enrollment_accepted_without_status",
        event_name: "enrollment.accepted",
        resource_type: "enrollment",
        resource_id: "enrl_remote_event_status"
      ),
      gateway_class:
    ).call

    assert result.success?
    deduction = employer.payroll_runs.sole.payroll_deductions.sole

    assert_equal "accepted", enrollment.reload.status
    assert_equal 8_100, deduction.amount_cents
    assert_equal "ready", deduction.status
    assert_equal "enrollment.accepted", deduction.metadata.fetch("last_webhook_event_name")
  ensure
    ENV.delete("VITABLE_CONNECT_API_KEY")
  end

  test "uses waived enrollment event action to zero deductions when resource omits status" do
    employer = @organization.employers.create!(name: "Waived Event Enrollment Employer", status: "active")
    employee = employer.employees.create!(
      first_name: "Quinn",
      last_name: "Waived",
      email: "quinn.waived@example.com",
      vitable_id: "empl_remote_quinn"
    )
    plan = employer.benefit_plans.create!(
      name: "Vitable Waived Care",
      category: "direct_primary_care",
      carrier: "Vitable",
      vitable_id: "bprd_remote_waived_care"
    )
    enrollment = employee.enrollments.create!(
      benefit_plan: plan,
      status: "accepted",
      accepted_at: 1.week.ago,
      vitable_id: "enrl_remote_waived"
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
      code: "VITABLE_WAIVED_CARE",
      amount_cents: 8_100,
      status: "ready"
    )
    ENV["VITABLE_CONNECT_API_KEY"] = "vit_apk_test_value"
    gateway_class = Class.new do
      define_method(:initialize) { |_connection| }
      define_method(:fetch_resource) do |_resource_type, resource_id|
        {
          data: {
            id: resource_id,
            employee_id: "empl_remote_quinn",
            benefit: {
              id: "bprd_remote_waived_care",
              name: "Vitable Waived Care"
            },
            employee_deduction_in_cents: 8_100
          }
        }
      end
    end

    result = Vitable::ProcessWebhookCommand.new(
      payload: webhook_payload.merge(
        event_id: "wevt_test_enrollment_waived_without_status",
        event_name: "enrollment.waived",
        resource_type: "enrollment",
        resource_id: "enrl_remote_waived"
      ),
      gateway_class:
    ).call

    assert result.success?
    assert_equal "waived", enrollment.reload.status
    assert_nil enrollment.accepted_at
    assert_equal 0, deduction.reload.amount_cents
    assert_equal "waived", deduction.status
    assert_equal "enrollment.waived", deduction.metadata.fetch("last_webhook_event_name")
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
    timestamp = Time.current.iso8601
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

  test "accepts a signed Vitable webhook that uses organization_external_id" do
    @connection.update!(webhook_secret_reference: "VITABLE_WEBHOOK_SECRET")
    ENV["VITABLE_WEBHOOK_SECRET"] = "whsec_test_value"
    payload = webhook_payload.except(:organization_id).merge(
      event_id: "wevt_test_signed_external_org",
      organization_external_id: @organization.external_id
    )
    raw_body = payload.to_json
    timestamp = Time.current.iso8601
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
    assert_equal @connection, event.integration_connection
    assert_equal @organization.external_id, event.organization_external_id
    assert_equal "verified", event.metadata.dig("signature_verification", "status")
  ensure
    ENV.delete("VITABLE_WEBHOOK_SECRET")
  end

  test "rejects SHA256 webhook signatures when webhook secret is configured" do
    @connection.update!(webhook_secret_reference: "VITABLE_WEBHOOK_SECRET")
    ENV["VITABLE_WEBHOOK_SECRET"] = "whsec_test_value"
    payload = webhook_payload.merge(event_id: "wevt_test_sha256_signature")
    raw_body = payload.to_json
    timestamp = Time.current.iso8601
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

  test "rejects raw-body signatures when timestamp header is present" do
    @connection.update!(webhook_secret_reference: "VITABLE_WEBHOOK_SECRET")
    ENV["VITABLE_WEBHOOK_SECRET"] = "whsec_test_value"
    payload = webhook_payload.merge(event_id: "wevt_test_timestamp_binding")
    raw_body = payload.to_json
    timestamp = Time.current.iso8601
    signature = Vitable::WebhookSignatureVerifier.sign(raw_body:, secret: ENV.fetch("VITABLE_WEBHOOK_SECRET"))

    assert_no_difference "WebhookEvent.count" do
      post api_v1_webhooks_vitable_path,
        params: payload,
        headers: signed_headers(timestamp:, signature:),
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
        headers: signed_headers(timestamp: Time.current.iso8601, signature: "not-a-valid-signature"),
        as: :json
    end

    assert_response :unauthorized
    response_payload = JSON.parse(response.body)
    assert_equal "signature_invalid", response_payload.fetch("signature")
  ensure
    ENV.delete("VITABLE_WEBHOOK_SECRET")
  end

  test "rejects signed webhooks with stale timestamp headers" do
    @connection.update!(webhook_secret_reference: "VITABLE_WEBHOOK_SECRET")
    ENV["VITABLE_WEBHOOK_SECRET"] = "whsec_test_value"
    payload = webhook_payload.merge(event_id: "wevt_test_stale_signature_timestamp")
    raw_body = payload.to_json
    timestamp = 10.minutes.ago.iso8601
    signature = Vitable::WebhookSignatureVerifier.sign(raw_body:, secret: ENV.fetch("VITABLE_WEBHOOK_SECRET"), timestamp:)

    assert_no_difference "WebhookEvent.count" do
      post api_v1_webhooks_vitable_path,
        params: payload,
        headers: signed_headers(timestamp:, signature:),
        as: :json
    end

    assert_response :unauthorized
    response_payload = JSON.parse(response.body)
    assert_equal "timestamp_out_of_tolerance", response_payload.fetch("signature")
  ensure
    ENV.delete("VITABLE_WEBHOOK_SECRET")
  end

  test "rejects signed webhooks with malformed timestamp headers" do
    @connection.update!(webhook_secret_reference: "VITABLE_WEBHOOK_SECRET")
    ENV["VITABLE_WEBHOOK_SECRET"] = "whsec_test_value"
    payload = webhook_payload.merge(event_id: "wevt_test_malformed_signature_timestamp")
    raw_body = payload.to_json
    timestamp = "not-a-timestamp"
    signature = Vitable::WebhookSignatureVerifier.sign(raw_body:, secret: ENV.fetch("VITABLE_WEBHOOK_SECRET"), timestamp:)

    assert_no_difference "WebhookEvent.count" do
      post api_v1_webhooks_vitable_path,
        params: payload,
        headers: signed_headers(timestamp:, signature:),
        as: :json
    end

    assert_response :unauthorized
    response_payload = JSON.parse(response.body)
    assert_equal "timestamp_invalid", response_payload.fetch("signature")
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
