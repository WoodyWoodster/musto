require "test_helper"

module Vitable
  class RunDemoSmokeCheckCommandTest < ActiveSupport::TestCase
    setup do
      ENV.delete("VITABLE_CONNECT_API_KEY")
      @organization = Organization.create!(name: "Smoke Org", external_id: "org_smoke")
      @connection = @organization.integration_connections.create!(
        provider: "vitable",
        environment: "demo",
        api_key_reference: "VITABLE_CONNECT_API_KEY",
        status: "pending",
        metadata: { "api_base_url" => "https://api.demo.vitablehealth.com" }
      )
    end

    test "runs read-only smoke checks and persists an auditable snapshot" do
      ENV["VITABLE_CONNECT_API_KEY"] = "vit_apk_test_value"

      result = RunDemoSmokeCheckCommand.new(
        dto: RunDemoSmokeCheckDto.new(
          connection_id: @connection.id,
          environment: "demo",
          api_key_reference: "VITABLE_CONNECT_API_KEY",
          requested_by: "test"
        ),
        gateway_class: successful_gateway_class
      ).call

      assert result.success?
      sync_run = result.record
      snapshot = @connection.reload.metadata.fetch("demo_smoke_check")

      assert_equal "succeeded", sync_run.status
      assert_equal "demo_smoke_check", sync_run.operation
      assert_equal "active", @connection.status
      assert_equal "https://api.demo.vitablehealth.com", snapshot.fetch("base_url")
      assert_equal "ready", snapshot.fetch("checks").find { |check| check.fetch("name") == "auth.issue_employer_access_token" }.fetch("status")
      assert_equal "ready", snapshot.fetch("checks").find { |check| check.fetch("name") == "auth.issue_employee_access_token" }.fetch("status")
      assert_equal 1, snapshot.dig("counts", "employers")
      assert_equal 1, snapshot.dig("counts", "groups")
      assert_equal 0, snapshot.dig("counts", "plans")
      assert_equal "empr_demo_123", snapshot.dig("samples", "employer_id")
      assert_includes snapshot.fetch("warnings").first, "zero plans"
      assert_not_includes sync_run.stats.to_json, "vit_at_secret"
    ensure
      ENV.delete("VITABLE_CONNECT_API_KEY")
    end

    test "records needs credentials when the configured key is unavailable" do
      result = RunDemoSmokeCheckCommand.new(
        dto: RunDemoSmokeCheckDto.new(
          connection_id: @connection.id,
          environment: "demo",
          api_key_reference: "VITABLE_CONNECT_API_KEY",
          requested_by: "test"
        ),
        gateway_class: successful_gateway_class
      ).call

      assert result.failure?
      sync_run = result.record
      assert_equal "needs_credentials", sync_run.status
      assert_match "VITABLE_CONNECT_API_KEY", sync_run.error_message
    end

    private

    def successful_gateway_class
      access_token_response = Data.define(:access_token)
      bound_token_response = Data.define(:access_token, :expires_in, :bound_entity)

      Class.new do
        define_method(:initialize) { |_connection| }
        define_method(:issue_access_token) { access_token_response.new(access_token: "vit_at_secret_value") }
        define_method(:issue_employer_access_token) { |employer_id| bound_token_response.new(access_token: "vit_at_employer_secret", expires_in: 3_600, bound_entity: { type: "employer", id: employer_id }) }
        define_method(:issue_employee_access_token) { |employee_id| bound_token_response.new(access_token: "vit_at_employee_secret", expires_in: 3_600, bound_entity: { type: "employee", id: employee_id }) }
        define_method(:list_all_employers) { { data: [ { id: "empr_demo_123", name: "Demo Employer" } ] } }
        define_method(:retrieve_employer) { |employer_id| { data: { id: employer_id, name: "Demo Employer" } } }
        define_method(:list_all_employer_employees) { |_employer_id| { data: [ { id: "empl_demo_123", email: "casey@example.com" } ] } }
        define_method(:list_all_employee_enrollments) { |_employee_id| { data: [ { id: "enrl_demo_123", status: "accepted" } ] } }
        define_method(:list_all_groups) { { data: [ { id: "grp_demo_123", name: "Demo Group" } ] } }
        define_method(:retrieve_group) { |group_id| { data: { id: group_id, name: "Demo Group" } } }
        define_method(:list_all_plans) { { data: [] } }
        define_method(:list_all_webhook_events) { { data: [ { id: "wevt_demo_123", event_name: "enrollment.accepted" } ] } }
      end
    end
  end
end
