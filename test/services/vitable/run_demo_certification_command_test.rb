require "test_helper"

module Vitable
  class RunDemoCertificationCommandTest < ActiveSupport::TestCase
    PUBLIC_WEBHOOK_URL = "https://public.example.test/api/v1/webhooks/vitable"

    setup do
      clear_vitable_env
      @organization = Organization.create!(name: "Certification Org", external_id: "org_certification")
      @connection = @organization.integration_connections.create!(
        provider: "vitable",
        environment: "demo",
        api_key_reference: Vitable::Configuration::DEFAULT_API_KEY_REFERENCE,
        webhook_secret_reference: Vitable::Configuration::DEFAULT_WEBHOOK_SECRET_REFERENCE,
        status: "pending"
      )
      @artifact_dir = Rails.root.join("tmp/test-vitable-certifications/#{@connection.id}")
    end

    test "certifies the complete demo surface and writes redacted artifacts" do
      set_vitable_env(
        Vitable::Configuration::DEFAULT_API_KEY_REFERENCE => "vit_apk_test_value",
        Vitable::Configuration::DEFAULT_WEBHOOK_SECRET_REFERENCE => "whsec_test_value"
      )

      result = command(gateway_class: successful_gateway_class).call

      assert result.success?
      sync_run = result.record
      report = result.value
      snapshot = @connection.reload.metadata.fetch("demo_certification")

      assert_equal "succeeded", sync_run.status
      assert_equal "demo_certification", sync_run.operation
      assert report.certified?
      assert_equal "full", report.scope
      assert_equal CertificationMatrix.cases.count, report.counts.fetch("passed_count")
      assert_equal 0, report.counts.fetch("failed_count")
      assert_equal "certified", snapshot.fetch("status")
      assert_equal "empr_cert_123", snapshot.dig("remote_ids", "employer_id")
      assert File.exist?(report.artifact_paths.fetch("json"))
      assert File.exist?(report.artifact_paths.fetch("markdown"))
      assert_not_empty @connection.api_request_logs
      assert_not_includes File.read(report.artifact_paths.fetch("json")), "vit_at_secret"
      assert_includes File.read(report.artifact_paths.fetch("markdown")), "Vitable Demo Certification"
    end

    test "certifies API scope without webhook proof inputs" do
      set_vitable_env(Vitable::Configuration::DEFAULT_API_KEY_REFERENCE => "vit_apk_test_value")

      result = command(
        gateway_class: successful_gateway_class,
        scope: "api",
        public_webhook_url: nil,
        webhook_secret_reference: nil
      ).call

      assert result.success?
      report = result.value

      assert report.certified?
      assert_equal "api", report.scope
      assert_equal "demo_api_certification", result.record.operation
      assert_nil report.public_webhook_url
      assert_equal CertificationMatrix.cases(scope: "api").count, report.counts.fetch("case_count")
      assert_equal CertificationMatrix.cases(scope: "api").count, report.counts.fetch("passed_count")
      assert_empty report.cases.select { |entry| entry.fetch("operation").start_with?("webhook") }
    end

    test "records needs credentials when the configured API key is unavailable" do
      result = command(gateway_class: successful_gateway_class).call

      assert result.failure?
      assert_equal "needs_credentials", result.record.status
      assert_match Vitable::Configuration::DEFAULT_API_KEY_REFERENCE, result.record.error_message
    end

    test "fails certification when a dependent endpoint cannot be proven" do
      set_vitable_env(
        Vitable::Configuration::DEFAULT_API_KEY_REFERENCE => "vit_apk_test_value",
        Vitable::Configuration::DEFAULT_WEBHOOK_SECRET_REFERENCE => "whsec_test_value"
      )

      result = command(gateway_class: successful_gateway_class(plan_id: nil)).call

      assert result.failure?
      assert_equal "failed", result.record.status
      assert_equal "failed", result.value.to_h.fetch("status")
      failed = result.value.cases.select { |entry| entry.fetch("status") == "failed" }
      assert failed.any? { |entry| entry.fetch("operation") == "group.member_sync.submit" }
      assert_match "remote Vitable plan ID", failed.find { |entry| entry.fetch("operation") == "group.member_sync.submit" }.fetch("error")
    end

    test "records Vitable API failures in the certification report" do
      set_vitable_env(
        Vitable::Configuration::DEFAULT_API_KEY_REFERENCE => "vit_apk_test_value",
        Vitable::Configuration::DEFAULT_WEBHOOK_SECRET_REFERENCE => "whsec_test_value"
      )

      result = command(gateway_class: api_failure_gateway_class).call

      assert result.failure?
      auth_case = result.value.cases.find { |entry| entry.fetch("operation") == "auth.issue_access_token" }
      assert_equal "failed", auth_case.fetch("status")
      assert_match "Vitable API request failed with status 401", auth_case.fetch("error")
      assert_not_includes result.value.to_h.to_json, "vit_apk_bad_error_body"
    end

    private

    def command(gateway_class:, scope: "full", public_webhook_url: PUBLIC_WEBHOOK_URL, webhook_secret_reference: Vitable::Configuration::DEFAULT_WEBHOOK_SECRET_REFERENCE)
      RunDemoCertificationCommand.new(
        dto: RunDemoCertificationDto.new(
          connection_id: @connection.id,
          environment: "demo",
          api_key_reference: Vitable::Configuration::DEFAULT_API_KEY_REFERENCE,
          webhook_secret_reference:,
          public_webhook_url:,
          requested_by: "test",
          artifact_dir: @artifact_dir.to_s,
          webhook_wait_seconds: 0,
          scope:
        ),
        gateway_class:
      )
    end

    def successful_gateway_class(plan_id: "plan_cert_123")
      public_webhook_url = PUBLIC_WEBHOOK_URL
      Class.new do
        define_singleton_method(:retrievable_resource_type?) do |resource_type|
          %w[employee employer enrollment webhook_event group eligibility_policy benefit_eligibility_policy].include?(resource_type.to_s)
        end

        define_singleton_method(:webhook_resource_type?) do |resource_type|
          %w[dependent plan_year employer payroll_deduction employee enrollment].include?(resource_type.to_s)
        end

        define_singleton_method(:payload_only_webhook_resource_type?) do |resource_type|
          %w[dependent payroll_deduction plan_year].include?(resource_type.to_s)
        end

        define_method(:initialize) { |connection| @connection = connection }

        define_method(:issue_access_token) do
          log("auth.issue_access_token", "POST", EndpointCatalog::AUTH_ACCESS_TOKENS, token_response)
        end

        define_method(:issue_employer_access_token) do |employer_id|
          log("auth.issue_employer_access_token", "POST", EndpointCatalog::AUTH_ACCESS_TOKENS, token_response.merge("data" => token_response.fetch("data").merge("bound_entity" => { "type" => "employer", "id" => employer_id })))
        end

        define_method(:issue_employee_access_token) do |employee_id|
          log("auth.issue_employee_access_token", "POST", EndpointCatalog::AUTH_ACCESS_TOKENS, token_response.merge("data" => token_response.fetch("data").merge("bound_entity" => { "type" => "employee", "id" => employee_id })))
        end

        define_method(:list_all_employers) do
          log("employer.list", "GET", EndpointCatalog::EMPLOYERS, { "data" => [] })
        end

        define_method(:create_employer) do |payload|
          log("employer.create", "POST", EndpointCatalog::EMPLOYERS, {
            "data" => {
              "id" => "empr_cert_123",
              "name" => payload.fetch(:name),
              "legal_name" => payload.fetch(:legal_name),
              "reference_id" => payload.fetch(:reference_id)
            }
          })
        end

        define_method(:retrieve_employer) do |employer_id|
          log("employer.retrieve", "GET", EndpointCatalog.path(:employer, id: employer_id), {
            "data" => {
              "id" => employer_id,
              "name" => "Musto Certification",
              "reference_id" => @connection.organization.employers.where(vitable_id: employer_id).first.then { |employer| "musto_employer_#{employer.id}" }
            }
          })
        end

        define_method(:update_employer_settings) do |employer_id, pay_frequency|
          log("employer.update_settings", "PUT", EndpointCatalog.path(:employer_settings, id: employer_id), {
            "data" => { "employer_id" => employer_id, "pay_frequency" => pay_frequency }
          })
        end

        define_method(:create_eligibility_policy) do |employer_id, _payload|
          log("employer.eligibility_policy.create", "POST", EndpointCatalog.path(:employer_eligibility_policies, id: employer_id), {
            "data" => { "id" => "bep_cert_123", "employer_id" => employer_id }
          })
        end

        define_method(:retrieve_eligibility_policy) do |policy_id|
          log("eligibility_policy.retrieve", "GET", EndpointCatalog.path(:benefit_eligibility_policy, id: policy_id), {
            "data" => { "id" => policy_id, "employer_id" => "empr_cert_123" }
          })
        end

        define_method(:list_all_plans) do
          data = plan_id.present? ? [ { "id" => plan_id, "name" => "Certification Plan" } ] : []
          log("plan.list", "GET", EndpointCatalog::PLANS, { "data" => data })
        end

        define_method(:submit_census_sync) do |employer_id, _employees|
          log("employer.census_sync", "POST", EndpointCatalog.path(:employer_census_sync, id: employer_id), {
            "data" => { "employer_id" => employer_id, "accepted_at" => Time.current.iso8601 }
          })
        end

        define_method(:list_all_employer_employees) do |employer_id|
          log("employer.list_employees", "GET", EndpointCatalog.path(:employer_employees, id: employer_id), {
            "data" => [
              {
                "id" => "empl_cert_123",
                "reference_id" => "remote_reference_cert",
                "email" => "benefits@example.com",
                "member_id" => "mbr_cert_123"
              }
            ]
          })
        end

        define_method(:retrieve_employee) do |employee_id|
          log("employee.retrieve", "GET", EndpointCatalog.path(:employee, id: employee_id), {
            "data" => {
              "id" => employee_id,
              "member_id" => "mbr_cert_123",
              "email" => "benefits@example.com",
              "status" => "active"
            }
          })
        end

        define_method(:list_all_employee_enrollments) do |employee_id|
          log("employee.list_enrollments", "GET", EndpointCatalog.path(:employee_enrollments, id: employee_id), {
            "data" => [
              {
                "id" => "enrl_cert_123",
                "employee_id" => employee_id,
                "plan_id" => plan_id || "plan_cert_123",
                "benefit" => { "id" => plan_id || "plan_cert_123", "name" => "Certification Plan" },
                "status" => "accepted"
              }
            ]
          })
        end

        define_method(:retrieve_enrollment) do |enrollment_id|
          log("enrollment.retrieve", "GET", EndpointCatalog.path(:enrollment, id: enrollment_id), {
            "data" => {
              "id" => enrollment_id,
              "employee_id" => "empl_cert_123",
              "plan_id" => plan_id || "plan_cert_123",
              "benefit" => { "id" => plan_id || "plan_cert_123", "name" => "Certification Plan" },
              "status" => "accepted"
            }
          })
        end

        define_method(:fetch_resource) do |resource_type, resource_id|
          case resource_type
          when "employer"
            retrieve_employer(resource_id)
          when "employee"
            retrieve_employee(resource_id)
          when "enrollment"
            retrieve_enrollment(resource_id)
          when "webhook_event"
            retrieve_webhook_event(resource_id)
          when "group"
            retrieve_group(resource_id)
          else
            raise ArgumentError, "Unsupported fake resource #{resource_type}"
          end
        end

        define_method(:list_all_groups) do
          log("group.list", "GET", EndpointCatalog::GROUPS, { "data" => [] })
        end

        define_method(:create_group) do |payload|
          log("group.create", "POST", EndpointCatalog::GROUPS, {
            "data" => {
              "id" => "grp_cert_123",
              "external_reference_id" => payload.fetch(:external_reference_id),
              "name" => payload.fetch(:name)
            }
          })
        end

        define_method(:retrieve_group) do |group_id|
          employer = @connection.organization.employers.detect { |record| record.settings.to_h[Vitable::CareGroupRepository::GROUP_ID_KEY] == group_id }
          log("group.retrieve", "GET", EndpointCatalog.path(:group, id: group_id), {
            "data" => {
              "id" => group_id,
              "external_reference_id" => "musto_care_group_#{employer.id}",
              "name" => employer.name
            }
          })
        end

        define_method(:update_group) do |group_id, payload|
          log("group.update", "PATCH", EndpointCatalog.path(:group, id: group_id), {
            "data" => {
              "id" => group_id,
              "external_reference_id" => payload.fetch(:external_reference_id),
              "name" => payload.fetch(:name)
            }
          })
        end

        define_method(:submit_group_member_sync) do |group_id, _members|
          log("group.member_sync.submit", "POST", EndpointCatalog.path(:group_members_sync, id: group_id), {
            "data" => { "request_id" => "gms_cert_123", "group_id" => group_id, "accepted_at" => Time.current.iso8601 }
          })
        end

        define_method(:retrieve_group_member_sync) do |group_id, request_id|
          log("group.member_sync.retrieve", "GET", EndpointCatalog.path(:group_member_sync_request, id: group_id, request_id: request_id), {
            "data" => {
              "request_id" => request_id,
              "group_id" => group_id,
              "accepted_at" => 2.minutes.ago.iso8601,
              "completed_at" => Time.current.iso8601,
              "results" => {
                "added_group_member_ids" => [ "mbr_cert_123" ],
                "removed_group_member_ids" => [],
                "failures" => []
              }
            }
          })
        end

        define_method(:list_all_webhook_events) do |limit: 100, **_filters|
          log("webhook_event.list", "GET", EndpointCatalog::WEBHOOK_EVENTS, {
            "data" => [ remote_webhook_event ]
          })
        end

        define_method(:retrieve_webhook_event) do |event_id|
          log("webhook_event.retrieve", "GET", EndpointCatalog.path(:webhook_event, id: event_id), {
            "data" => remote_webhook_event.merge("id" => event_id)
          })
        end

        define_method(:list_webhook_event_deliveries) do |event_id|
          log("webhook_event.list_deliveries", "GET", EndpointCatalog.path(:webhook_event_deliveries, id: event_id), {
            "data" => [
              {
                "id" => "del_cert_123",
                "webhook_event_id" => event_id,
                "subscription_url" => public_webhook_url,
                "status" => "delivered"
              }
            ]
          })
        end

        define_method(:token_response) do
          {
            "data" => {
              "access_token" => "vit_at_secret_value",
              "expires_in" => 3600,
              "token_type" => "Bearer"
            }
          }
        end

        define_method(:remote_webhook_event) do
          {
            "id" => "wevt_remote_cert",
            "organization_id" => @connection.organization.external_id,
            "event_name" => "employer.eligibility_policy_created",
            "resource_type" => "employer",
            "resource_id" => "empr_cert_123",
            "created_at" => Time.current.iso8601
          }
        end

        define_method(:log) do |operation, method, path, response|
          @connection.api_request_logs.create!(
            operation:,
            method:,
            path:,
            status_code: 200,
            duration_ms: 1,
            request_body: {},
            response_body: PayloadRedactor.redact(response.deep_stringify_keys)
          )
          response
        end
      end
    end

    def api_failure_gateway_class
      Class.new do
        define_method(:initialize) { |_connection| }

        define_method(:issue_access_token) do
          raise VitableConnect::Errors::AuthenticationError.new(
            url: URI("https://api.demo.vitablehealth.com/v1/auth/access-tokens"),
            status: 401,
            headers: {},
            body: {
              error: "invalid_api_key",
              api_key: "vit_apk_bad_error_body"
            },
            request: nil,
            response: nil
          )
        end
      end
    end
  end
end
