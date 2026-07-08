require "fileutils"
require "json"
require "securerandom"
require "uri"
require "vitable_connect"

module Vitable
  class RunDemoCertificationCommand < ApplicationCommand
    CertificationFailed = Class.new(StandardError)
    SignedWebhookRequest = Data.define(:payload, :raw_body, :headers) do
      def header(name)
        headers[name]
      end
    end

    LOCAL_WEBHOOK_EVENT_NAMES = {
      "dependent" => "dependent.updated",
      "employee" => "employee.eligibility_granted",
      "employer" => "employer.eligibility_policy_created",
      "enrollment" => "enrollment.accepted",
      "payroll_deduction" => "employee.deduction_created",
      "plan_year" => "plan_year.updated"
    }.freeze
    LOCAL_WEBHOOK_RESOURCE_TYPES = LOCAL_WEBHOOK_EVENT_NAMES.keys.freeze
    PAY_FREQUENCY = "bi_weekly"

    def initialize(dto:, repository: IntegrationRepository.new, gateway_class: ClientGateway, process_webhook_command_class: ProcessWebhookCommand, clock: -> { Time.current }, sleeper: ->(seconds) { sleep(seconds) })
      @dto = dto
      @repository = repository
      @gateway_class = gateway_class
      @process_webhook_command_class = process_webhook_command_class
      @clock = clock
      @sleeper = sleeper
      @rows = []
      @context = {}
    end

    def call
      @connection = certification_connection
      @sync_run = @repository.create_demo_certification_run(
        connection: @connection,
        requested_by: @dto.requested_by,
        matrix: CertificationMatrix.cases
      )

      unless @connection.credentials_present?
        @sync_run = @repository.mark_demo_certification_needs_credentials(@sync_run)
        return failure(record: @sync_run, errors: @sync_run.error_message)
      end

      configure_connection_for_webhooks
      @gateway = @gateway_class.new(@connection)
      @context = base_context

      run_certification_cases
      result = build_result
      write_artifacts(result)
      finish_run(result)
    rescue VitableConnect::Errors::APIError, ActiveRecord::RecordInvalid, KeyError, ArgumentError => e
      result = build_result(error: e) if @connection
      write_artifacts(result) if result
      @sync_run = @repository.fail_demo_certification_run(@sync_run, e, result:) if @sync_run
      failure(record: @sync_run, value: result, errors: PayloadRedactor.error_with_class(e))
    end

    private

    def certification_connection
      if @dto.connection_id.present?
        @repository.find_connection(@dto.connection_id)
      else
        @repository.demo_certification_connection(
          environment: @dto.environment,
          api_key_reference: @dto.api_key_reference
        )
      end
    end

    def configure_connection_for_webhooks
      return if @dto.webhook_secret_reference.blank?
      return if @connection.webhook_secret_reference == @dto.webhook_secret_reference

      @connection.update!(webhook_secret_reference: @dto.webhook_secret_reference)
    end

    def base_context
      checked_at = @clock.call
      certification_id = "musto-cert-#{checked_at.utc.strftime("%Y%m%d%H%M%S")}-#{SecureRandom.hex(4)}"

      {
        certification_id:,
        checked_at:,
        prefix: certification_id,
        remote_ids: {},
        employer_name: "Musto Certification #{certification_id}",
        employee_email: "benefits+#{certification_id}@example.com",
        phone: "5550101234",
        ein: "#{SecureRandom.random_number(90) + 10}-#{SecureRandom.random_number(10_000_000).to_s.rjust(7, "0")}"
      }
    end

    def run_certification_cases
      certify_auth_token
      certify_employer_list
      certify_employer_create
      certify_employer_retrieve
      certify_employer_settings
      certify_employer_bound_token
      certify_eligibility_policy_create
      certify_eligibility_policy_retrieve
      certify_plan_list
      certify_census_sync
      certify_employer_employees
      certify_employee_retrieve
      certify_employee_bound_token
      certify_employee_enrollments
      certify_enrollment_retrieve
      certify_group_list
      certify_group_create
      certify_group_retrieve
      certify_group_update
      certify_group_member_sync_submit
      certify_group_member_sync_retrieve
      certify_webhook_event_list
      certify_webhook_event_retrieve
      certify_webhook_event_deliveries
      certify_remote_webhook_delivery
      certify_local_signed_webhook_fixtures
    end

    def certify_auth_token
      certify_case("auth.issue_access_token") do
        response = @gateway.issue_access_token
        RemoteAccessTokenResponseDto.from_response(serialize_response(response)).validate!(response_label: "Vitable certification auth token")
        { details: { "token_issued" => true } }
      end
    end

    def certify_employer_bound_token
      certify_case("auth.issue_employer_access_token") do
        employer_id = require_context(:employer_id, "remote employer ID")
        response = @gateway.issue_employer_access_token(employer_id)
        RemoteAccessTokenResponseDto.from_response(serialize_response(response)).validate!(response_label: "Vitable certification employer token")
        { remote_ids: { "employer_id" => employer_id }, details: { "token_issued" => true } }
      end
    end

    def certify_employee_bound_token
      certify_case("auth.issue_employee_access_token") do
        employee_id = require_context(:employee_id, "remote employee ID")
        response = @gateway.issue_employee_access_token(employee_id)
        RemoteAccessTokenResponseDto.from_response(serialize_response(response)).validate!(response_label: "Vitable certification employee token")
        { remote_ids: { "employee_id" => employee_id }, details: { "token_issued" => true } }
      end
    end

    def certify_employer_list
      certify_case("employer.list") do
        employers = page_data(@gateway.list_all_employers)
        { details: { "remote_count" => employers.count } }
      end
    end

    def certify_employer_create
      certify_case("employer.create") do
        local_employer = ensure_local_employer
        payload = employer_payload(local_employer)
        response = @gateway.create_employer(payload)
        dto = RemoteEmployerDto
          .from_hash(serialize_response(response))
          .validate_create!(expected_reference_id: payload.fetch(:reference_id))
        local_employer.update!(vitable_id: dto.remote_employer_id)
        @context[:employer_id] = dto.remote_employer_id
        @context[:local_employer] = local_employer
        remember_remote_id("employer_id", dto.remote_employer_id)
        {
          remote_ids: { "employer_id" => dto.remote_employer_id },
          details: { "reference_id" => payload.fetch(:reference_id) }
        }
      end
    end

    def certify_employer_retrieve
      certify_case("employer.retrieve") do
        employer_id = require_context(:employer_id, "remote employer ID")
        response = @gateway.retrieve_employer(employer_id)
        RemoteEmployerDto.from_hash(serialize_response(response)).validate_identity!(response_label: "Vitable certification employer")
        reconciliation = matched_reconciliation!("employer", employer_id, response)
        { remote_ids: { "employer_id" => employer_id }, reconciliation: }
      end
    end

    def certify_employer_settings
      certify_case("employer.update_settings") do
        employer_id = require_context(:employer_id, "remote employer ID")
        response = @gateway.update_employer_settings(employer_id, PAY_FREQUENCY)
        RemoteEmployerSettingsResponseDto.from_hash(serialize_response(response)).validate!(expected_pay_frequency: PAY_FREQUENCY)
        { remote_ids: { "employer_id" => employer_id }, details: { "pay_frequency" => PAY_FREQUENCY } }
      end
    end

    def certify_eligibility_policy_create
      certify_case("employer.eligibility_policy.create") do
        employer_id = require_context(:employer_id, "remote employer ID")
        response = @gateway.create_eligibility_policy(employer_id, eligibility_policy_payload)
        dto = RemoteEligibilityPolicyResponseDto.from_hash(serialize_response(response)).validate!(expected_employer_id: employer_id)
        @context[:eligibility_policy_id] = dto.remote_policy_id
        remember_remote_id("eligibility_policy_id", dto.remote_policy_id)
        { remote_ids: { "employer_id" => employer_id, "eligibility_policy_id" => dto.remote_policy_id } }
      end
    end

    def certify_eligibility_policy_retrieve
      certify_case("eligibility_policy.retrieve") do
        policy_id = require_context(:eligibility_policy_id, "remote eligibility policy ID")
        employer_id = require_context(:employer_id, "remote employer ID")
        response = @gateway.retrieve_eligibility_policy(policy_id)
        RemoteEligibilityPolicyResponseDto.from_hash(serialize_response(response)).validate!(expected_employer_id: employer_id)
        { remote_ids: { "employer_id" => employer_id, "eligibility_policy_id" => policy_id } }
      end
    end

    def certify_plan_list
      certify_case("plan.list") do
        plans = page_data(@gateway.list_all_plans)
        plan_id = sample_id(plans.first)
        @context[:plan_id] = plan_id if plan_id.present?
        remember_remote_id("plan_id", plan_id) if plan_id.present?
        ensure_local_plan(plan_id) if plan_id.present?
        { remote_ids: { "plan_id" => plan_id }.compact, details: { "remote_count" => plans.count } }
      end
    end

    def certify_census_sync
      certify_case("employer.census_sync") do
        employer_id = require_context(:employer_id, "remote employer ID")
        local_employee = ensure_local_employee
        response = @gateway.submit_census_sync(employer_id, [ census_employee_payload(local_employee) ])
        RemoteCensusSyncResponseDto.from_hash(serialize_response(response)).validate!(expected_employer_id: employer_id)
        { remote_ids: { "employer_id" => employer_id }, details: { "employee_reference_id" => employee_reference_id(local_employee) } }
      end
    end

    def certify_employer_employees
      certify_case("employer.list_employees") do
        employer_id = require_context(:employer_id, "remote employer ID")
        employees = page_data(@gateway.list_all_employer_employees(employer_id))
        employee = employees.find { |entry| entry["reference_id"] == employee_reference_id(ensure_local_employee) } || employees.first
        employee_id = sample_id(employee)
        if employee_id.present?
          @context[:employee_id] = employee_id
          remember_remote_id("employee_id", employee_id)
          ensure_local_employee.update!(vitable_id: employee_id)
        end
        { remote_ids: { "employer_id" => employer_id, "employee_id" => employee_id }.compact, details: { "remote_count" => employees.count } }
      end
    end

    def certify_employee_retrieve
      certify_case("employee.retrieve") do
        employee_id = require_context(:employee_id, "remote employee ID")
        response = @gateway.retrieve_employee(employee_id)
        RemoteEmployeeDto.from_hash(serialize_response(response)).validate_identity!(response_label: "Vitable certification employee")
        reconciliation = matched_reconciliation!("employee", employee_id, response)
        { remote_ids: { "employee_id" => employee_id }, reconciliation: }
      end
    end

    def certify_employee_enrollments
      certify_case("employee.list_enrollments") do
        employee_id = require_context(:employee_id, "remote employee ID")
        enrollments = page_data(@gateway.list_all_employee_enrollments(employee_id))
        enrollment = enrollments.first
        enrollment_id = sample_id(enrollment)
        if enrollment_id.present?
          @context[:enrollment_id] = enrollment_id
          remember_remote_id("enrollment_id", enrollment_id)
          ensure_local_enrollment(enrollment_id)
        end
        { remote_ids: { "employee_id" => employee_id, "enrollment_id" => enrollment_id }.compact, details: { "remote_count" => enrollments.count } }
      end
    end

    def certify_enrollment_retrieve
      certify_case("enrollment.retrieve") do
        enrollment_id = require_context(:enrollment_id, "remote enrollment ID")
        response = @gateway.retrieve_enrollment(enrollment_id)
        RemoteEnrollmentDto.from_hash(serialize_response(response)).validate_identity!(response_label: "Vitable certification enrollment")
        reconciliation = matched_reconciliation!("enrollment", enrollment_id, response)
        { remote_ids: { "enrollment_id" => enrollment_id }, reconciliation: }
      end
    end

    def certify_group_list
      certify_case("group.list") do
        groups = page_data(@gateway.list_all_groups)
        { details: { "remote_count" => groups.count } }
      end
    end

    def certify_group_create
      certify_case("group.create") do
        local_employer = require_context(:local_employer, "local certification employer")
        response = @gateway.create_group(group_payload(local_employer))
        dto = RemoteGroupDto.from_hash(serialize_response(response)).validate_identity!(response_label: "Vitable certification group")
        @context[:group_id] = dto.group_id
        remember_remote_id("group_id", dto.group_id)
        local_employer.update!(settings: local_employer.settings.to_h.stringify_keys.merge(CareGroupRepository::GROUP_ID_KEY => dto.group_id))
        { remote_ids: { "group_id" => dto.group_id }, details: { "external_reference_id" => group_reference_id(local_employer) } }
      end
    end

    def certify_group_retrieve
      certify_case("group.retrieve") do
        group_id = require_context(:group_id, "remote group ID")
        response = @gateway.retrieve_group(group_id)
        RemoteGroupDto.from_hash(serialize_response(response)).validate_identity!(response_label: "Vitable certification group")
        reconciliation = matched_reconciliation!("group", group_id, response)
        { remote_ids: { "group_id" => group_id }, reconciliation: }
      end
    end

    def certify_group_update
      certify_case("group.update") do
        group_id = require_context(:group_id, "remote group ID")
        local_employer = require_context(:local_employer, "local certification employer")
        payload = group_payload(local_employer).merge(name: "#{local_employer.name} Updated")
        response = @gateway.update_group(group_id, payload)
        RemoteGroupDto.from_hash(serialize_response(response)).validate_identity!(response_label: "Vitable certification updated group")
        { remote_ids: { "group_id" => group_id }, details: { "name" => payload.fetch(:name) } }
      end
    end

    def certify_group_member_sync_submit
      certify_case("group.member_sync.submit") do
        group_id = require_context(:group_id, "remote group ID")
        plan_id = require_context(:plan_id, "remote Vitable plan ID")
        member = group_member_payload(ensure_local_employee, plan_id)
        response = @gateway.submit_group_member_sync(group_id, [ member ])
        dto = RemoteCareMemberSyncResponseDto.from_hash(serialize_response(response)).validate_submit!(expected_group_id: group_id)
        @context[:member_sync_request_id] = dto.request_id
        remember_remote_id("group_member_sync_request_id", dto.request_id)
        { remote_ids: { "group_id" => group_id, "request_id" => dto.request_id } }
      end
    end

    def certify_group_member_sync_retrieve
      certify_case("group.member_sync.retrieve") do
        group_id = require_context(:group_id, "remote group ID")
        request_id = require_context(:member_sync_request_id, "remote group member sync request ID")
        response = @gateway.retrieve_group_member_sync(group_id, request_id)
        dto = RemoteCareMemberSyncResponseDto.from_hash(serialize_response(response)).validate_refresh!(expected_group_id: group_id, expected_request_id: request_id)
        { remote_ids: { "group_id" => group_id, "request_id" => dto.request_id } }
      end
    end

    def certify_webhook_event_list
      certify_case("webhook_event.list") do
        events = page_data(@gateway.list_all_webhook_events(limit: 100))
        event_id = sample_id(events.first)
        @context[:webhook_event_id] = event_id if event_id.present?
        @context[:remote_webhook_events] = events
        remember_remote_id("webhook_event_id", event_id) if event_id.present?
        { remote_ids: { "webhook_event_id" => event_id }.compact, details: { "remote_count" => events.count } }
      end
    end

    def certify_webhook_event_retrieve
      certify_case("webhook_event.retrieve") do
        event_id = require_context(:webhook_event_id, "remote webhook event ID")
        response = @gateway.retrieve_webhook_event(event_id)
        dto = RemoteWebhookEventDto.from_remote_event(serialize_response(response))
        raise ArgumentError, "Vitable certification webhook event #{event_id} did not include retrievable event attributes" unless dto

        reconciliation = matched_reconciliation!("webhook_event", event_id, response)
        { remote_ids: { "webhook_event_id" => event_id }, reconciliation: }
      end
    end

    def certify_webhook_event_deliveries
      certify_case("webhook_event.list_deliveries") do
        event_id = require_context(:webhook_event_id, "remote webhook event ID")
        deliveries = page_data(@gateway.list_webhook_event_deliveries(event_id))
        @context[:webhook_deliveries] = deliveries
        delivery_id = sample_id(deliveries.first)
        { remote_ids: { "webhook_event_id" => event_id, "delivery_id" => delivery_id }.compact, details: { "remote_count" => deliveries.count } }
      end
    end

    def certify_remote_webhook_delivery
      certify_case("webhook.remote_delivery") do
        raise ArgumentError, "VITABLE_PUBLIC_WEBHOOK_URL is required for real Vitable webhook delivery proof" if @dto.public_webhook_url.blank?

        @sleeper.call(@dto.webhook_wait_seconds) if @dto.webhook_wait_seconds.to_i.positive?
        event_id = require_context(:webhook_event_id, "remote webhook event ID")
        delivery = matching_public_delivery
        raise ArgumentError, "No remote webhook delivery matched #{@dto.public_webhook_url}" unless delivery

        local_event = WebhookEvent.find_by(event_id:)
        raise ArgumentError, "No local WebhookEvent was received for remote event #{event_id}" unless local_event

        {
          remote_ids: { "webhook_event_id" => event_id, "delivery_id" => sample_id(delivery) }.compact,
          details: {
            "public_webhook_url" => @dto.public_webhook_url,
            "local_webhook_event_id" => local_event.id,
            "local_status" => local_event.status
          }
        }
      end
    end

    def certify_local_signed_webhook_fixtures
      certify_case("webhook.local_signed_fixtures") do
        secret = webhook_secret!
        fixtures = LOCAL_WEBHOOK_RESOURCE_TYPES.map do |resource_type|
          process_signed_fixture(resource_type, secret)
        end
        {
          remote_ids: fixtures.to_h { |entry| [ "#{entry.fetch("resource_type")}_id", entry.fetch("resource_id") ] },
          details: {
            "fixture_count" => fixtures.count,
            "fixtures" => fixtures
          }
        }
      end
    end

    def certify_case(key)
      definition = CertificationMatrix.find!(key)
      before_log_id = latest_request_log_id
      value = yield
      row = certification_row(
        definition,
        status: "passed",
        request_log_ids: request_log_ids_since(before_log_id),
        value:
      )
      @rows << row
      row
    rescue StandardError => e
      row = certification_row(
        definition,
        status: "failed",
        request_log_ids: request_log_ids_since(before_log_id),
        error: e
      )
      @rows << row
      row
    end

    def certification_row(definition, status:, request_log_ids:, value: {}, error: nil)
      {
        "key" => definition.fetch(:key),
        "resource_type" => definition.fetch(:resource_type),
        "method" => definition.fetch(:method),
        "endpoint" => definition.fetch(:endpoint),
        "operation" => definition.fetch(:operation),
        "transport" => definition.fetch(:transport, "sdk"),
        "demo_supported" => definition.fetch(:demo_supported),
        "status" => status,
        "request_log_ids" => request_log_ids,
        "remote_ids" => PayloadRedactor.redact(value.to_h.fetch(:remote_ids, {}).deep_stringify_keys),
        "reconciliation" => PayloadRedactor.redact(value.to_h.fetch(:reconciliation, {}).deep_stringify_keys),
        "details" => PayloadRedactor.redact(value.to_h.fetch(:details, {}).deep_stringify_keys)
      }.tap do |row|
        row["error"] = PayloadRedactor.error_message(error) if error
      end
    end

    def build_result(error: nil)
      checked_at = @context.fetch(:checked_at, @clock.call)
      remote_ids = @context.fetch(:remote_ids, {})
      failed_count = @rows.count { |entry| entry.fetch("status") != "passed" }
      counts = {
        "case_count" => CertificationMatrix.cases.count,
        "passed_count" => @rows.count { |entry| entry.fetch("status") == "passed" },
        "failed_count" => failed_count,
        "missing_case_count" => CertificationMatrix.cases.count - @rows.count,
        "write_case_count" => @rows.count { |entry| entry.fetch("method").in?(%w[POST PUT PATCH]) && entry.fetch("status") == "passed" },
        "get_case_count" => @rows.count { |entry| entry.fetch("method") == "GET" && entry.fetch("status") == "passed" }
      }
      counts["fatal_error"] = PayloadRedactor.error_message(error) if error

      DemoCertificationResultDto.new(
        certification_id: @context.fetch(:certification_id, "musto-cert-unstarted"),
        environment: @connection&.environment || @dto.environment,
        base_url: @connection&.sdk_base_url || Configuration::PRODUCTION_API_BASE_URL,
        checked_at:,
        sdk_version: VitableConnect::VERSION,
        public_webhook_url: @dto.public_webhook_url,
        cases: @rows,
        counts:,
        remote_ids: PayloadRedactor.redact(remote_ids.deep_stringify_keys),
        artifact_paths: artifact_paths
      )
    end

    def finish_run(result)
      if result.certified?
        @sync_run = @repository.succeed_demo_certification_run(@connection, @sync_run, result)
        success(record: @sync_run, value: result)
      else
        error = CertificationFailed.new("Vitable demo certification failed #{result.counts.fetch("failed_count")} case(s)")
        @sync_run = @repository.fail_demo_certification_run(@sync_run, error, result:)
        failure(record: @sync_run, value: result, errors: error.message)
      end
    end

    def write_artifacts(result)
      FileUtils.mkdir_p(@dto.artifact_dir)
      File.write(artifact_paths.fetch("json"), JSON.pretty_generate(result.to_h))
      File.write(artifact_paths.fetch("markdown"), result.to_markdown)
    end

    def artifact_paths
      return @artifact_paths if @artifact_paths

      id = @context.fetch(:certification_id, "musto-cert-unstarted")
      @artifact_paths = {
        "json" => File.join(@dto.artifact_dir, "#{id}.json"),
        "markdown" => File.join(@dto.artifact_dir, "#{id}.md")
      }
    end

    def latest_request_log_id
      @connection.api_request_logs.maximum(:id).to_i
    end

    def request_log_ids_since(id)
      @connection.api_request_logs.where("id > ?", id).order(:id).pluck(:id)
    end

    def remember_remote_id(key, value)
      return if value.blank?

      @context.fetch(:remote_ids)[key] = value
    end

    def require_context(key, label)
      value = @context[key]
      raise ArgumentError, "#{label} is required before this certification case can run" if value.blank?

      value
    end

    def employer_payload(local_employer)
      {
        name: @context.fetch(:employer_name),
        legal_name: "#{@context.fetch(:employer_name)} LLC",
        ein: @context.fetch(:ein),
        email: @context.fetch(:employee_email),
        phone_number: @context.fetch(:phone),
        reference_id: "musto_employer_#{local_employer.id}",
        address: address_payload
      }
    end

    def eligibility_policy_payload
      {
        classification: "All",
        waiting_period: "1st of the following month"
      }
    end

    def census_employee_payload(local_employee)
      {
        reference_id: employee_reference_id(local_employee),
        first_name: local_employee.first_name,
        last_name: local_employee.last_name,
        email: local_employee.email,
        phone: @context.fetch(:phone),
        date_of_birth: local_employee.date_of_birth.iso8601,
        start_date: local_employee.start_on.iso8601,
        compensation_type: "Salary",
        employee_class: "Full Time",
        address: address_payload
      }
    end

    def group_payload(local_employer)
      {
        external_reference_id: group_reference_id(local_employer),
        name: local_employer.name
      }
    end

    def group_member_payload(local_employee, plan_id)
      {
        reference_id: employee_reference_id(local_employee),
        first_name: local_employee.first_name,
        last_name: local_employee.last_name,
        email: local_employee.email,
        phone: @context.fetch(:phone),
        date_of_birth: local_employee.date_of_birth.iso8601,
        plan_id:,
        address: address_payload
      }
    end

    def address_payload
      {
        address_line_1: "100 Market Street",
        city: "Philadelphia",
        state: "PA",
        zipcode: "19103"
      }
    end

    def ensure_local_employer
      return @context[:local_employer] if @context[:local_employer]

      employer = @connection.organization.employers.create!(
        name: @context.fetch(:employer_name),
        legal_name: "#{@context.fetch(:employer_name)} LLC",
        ein: @context.fetch(:ein),
        status: "onboarded",
        onboarded_at: @clock.call,
        settings: {
          "pay_frequency" => "biweekly",
          "billing_email" => @context.fetch(:employee_email),
          "billing_phone" => @context.fetch(:phone)
        }
      )
      employer.departments.create!(name: "Certification", code: "CERT")
      employer.work_locations.create!(
        name: "Certification HQ",
        address_line1: "100 Market Street",
        city: "Philadelphia",
        state: "PA",
        postal_code: "19103"
      )
      @context[:local_employer] = employer
    end

    def ensure_local_employee
      return @context[:local_employee] if @context[:local_employee]

      employer = ensure_local_employer
      employee = employer.employees.create!(
        first_name: "Casey",
        last_name: "Certification",
        email: @context.fetch(:employee_email),
        employment_status: "active",
        onboarding_status: "complete",
        pay_type: "salary",
        compensation_cents: 9_000_000,
        date_of_birth: Date.new(1990, 1, 1),
        start_on: Date.current,
        department: employer.departments.find_by!(code: "CERT"),
        work_location: employer.work_locations.find_by!(name: "Certification HQ"),
        metadata: { "phone" => @context.fetch(:phone) }
      )
      @context[:local_employee] = employee
    end

    def ensure_local_plan(plan_id)
      return @context[:local_plan] if @context[:local_plan]

      plan = ensure_local_employer.benefit_plans.create!(
        name: "Vitable Certification Plan",
        carrier: "Vitable",
        category: "direct_primary_care",
        review_status: "published",
        status: "available",
        plan_year: Date.current.year,
        effective_on: Date.current.beginning_of_year,
        expires_on: Date.current.end_of_year,
        monthly_premium_cents: 10_000,
        employee_contribution_cents: 1_000,
        employer_contribution_cents: 9_000,
        vitable_id: plan_id
      )
      @context[:local_plan] = plan
    end

    def ensure_local_enrollment(enrollment_id)
      return @context[:local_enrollment] if @context[:local_enrollment]

      plan = ensure_local_plan(@context.fetch(:plan_id))
      enrollment = ensure_local_employee.enrollments.create!(
        benefit_plan: plan,
        status: "accepted",
        coverage_level: "employee",
        effective_on: Date.current.beginning_of_month,
        accepted_at: @clock.call,
        vitable_id: enrollment_id
      )
      @context[:local_enrollment] = enrollment
    end

    def ensure_local_payload_only_records
      return if @context[:local_dependent] && @context[:local_deduction]

      employee = ensure_local_employee
      plan = @context[:local_plan] || ensure_local_plan(@context[:plan_id] || "plan_certification_local")
      enrollment = @context[:local_enrollment] || employee.enrollments.find_or_create_by!(benefit_plan: plan) do |record|
        record.status = "accepted"
        record.coverage_level = "employee"
        record.effective_on = Date.current.beginning_of_month
        record.accepted_at = @clock.call
      end
      payroll_run = ensure_local_employer.payroll_runs.create!(
        period_start_on: Date.current.beginning_of_month,
        period_end_on: Date.current.end_of_month,
        pay_date: Date.current.end_of_month + 5.days,
        status: "draft",
        gross_pay_cents: 750_000
      )
      deduction = payroll_run.payroll_deductions.create!(
        employee:,
        enrollment:,
        code: "VITABLE_CERTIFICATION",
        amount_cents: 1_000,
        status: "ready",
        vitable_id: "pded_#{@context.fetch(:certification_id)}"
      )
      dependent = employee.dependents.create!(
        first_name: "Harper",
        last_name: "Certification",
        relationship: "child",
        date_of_birth: Date.new(2018, 3, 4),
        enrollment_status: "enrolled",
        eligibility_status: "eligible",
        vitable_id: "dep_#{@context.fetch(:certification_id)}"
      )

      @context[:local_enrollment] ||= enrollment
      @context[:local_deduction] = deduction
      @context[:local_dependent] = dependent
    end

    def employee_reference_id(local_employee)
      "musto_employee_#{local_employee.id}"
    end

    def group_reference_id(local_employer)
      "musto_care_group_#{local_employer.id}"
    end

    def matched_reconciliation!(resource_type, resource_id, response)
      reconciliation = @repository.reconcile_fetched_resource(
        connection: @connection,
        resource_type:,
        resource_id:,
        response:
      )
      metadata = reconciliation.to_metadata
      return metadata if metadata.fetch("status") == "matched"

      raise ArgumentError, "Vitable #{resource_type} reconciliation returned #{metadata.fetch("status")}"
    end

    def matching_public_delivery
      Array(@context[:webhook_deliveries]).find { |delivery| delivery_matches_public_url?(delivery) }
    end

    def delivery_matches_public_url?(delivery)
      json = JSON.generate(delivery)
      return true if json.include?(@dto.public_webhook_url)

      host = URI.parse(@dto.public_webhook_url).host
      host.present? && json.include?(host)
    rescue URI::InvalidURIError
      false
    end

    def webhook_secret!
      raise ArgumentError, "#{@connection.webhook_secret_reference} is required for signed local webhook fixtures" if @connection.webhook_secret.blank?

      @connection.webhook_secret
    end

    def process_signed_fixture(resource_type, secret)
      ensure_local_payload_only_records if resource_type.in?(%w[dependent payroll_deduction plan_year])
      payload = local_webhook_payload(resource_type)
      raw_body = JSON.generate(payload.deep_stringify_keys)
      timestamp = @clock.call.to_i.to_s
      signature = WebhookSignatureVerifier.sign(raw_body:, secret:, timestamp:)
      verification = WebhookSignatureVerifier.new.verify(
        SignedWebhookRequest.new(
          payload: JSON.parse(raw_body),
          raw_body:,
          headers: {
            "X-Vitable-Signature" => "sha512=#{signature}",
            "X-Vitable-Timestamp" => timestamp
          }
        )
      )
      raise ArgumentError, "Signed webhook fixture for #{resource_type} was not verified: #{verification.detail}" unless verification.status == "verified"

      result = @process_webhook_command_class.new(
        payload: JSON.parse(raw_body),
        repository: @repository,
        signature_verification: verification,
        gateway_class: @gateway_class
      ).call
      raise ArgumentError, "Signed webhook fixture for #{resource_type} failed: #{result.errors.to_sentence}" if result.failure?

      reconciliation = result.record.metadata.to_h.fetch("resource_reconciliation", {})
      {
        "resource_type" => resource_type,
        "resource_id" => payload.fetch(:resource_id),
        "event_id" => result.record.event_id,
        "status" => result.record.status,
        "signature_status" => verification.status,
        "reconciliation_status" => reconciliation.fetch("status", nil)
      }
    end

    def local_webhook_payload(resource_type)
      resource_id = local_webhook_resource_id(resource_type)
      {
        event_id: "wevt_#{@context.fetch(:certification_id)}_#{resource_type}",
        organization_id: @connection.organization.external_id,
        event_name: LOCAL_WEBHOOK_EVENT_NAMES.fetch(resource_type),
        resource_type:,
        resource_id:,
        created_at: @clock.call.iso8601,
        data: local_webhook_resource_payload(resource_type, resource_id)
      }.compact
    end

    def local_webhook_resource_id(resource_type)
      case resource_type
      when "employer"
        require_context(:employer_id, "remote employer ID")
      when "employee"
        require_context(:employee_id, "remote employee ID")
      when "enrollment"
        require_context(:enrollment_id, "remote enrollment ID")
      when "dependent"
        @context.fetch(:local_dependent).vitable_id
      when "payroll_deduction"
        @context.fetch(:local_deduction).vitable_id
      when "plan_year"
        "pyr_#{@context.fetch(:certification_id)}"
      end
    end

    def local_webhook_resource_payload(resource_type, resource_id)
      case resource_type
      when "dependent"
        dependent_payload(resource_id)
      when "payroll_deduction"
        payroll_deduction_payload(resource_id)
      when "plan_year"
        plan_year_payload(resource_id)
      end
    end

    def dependent_payload(resource_id)
      employee = ensure_local_employee
      dependent = @context.fetch(:local_dependent)
      {
        id: resource_id,
        employee_id: employee.vitable_id,
        employee_reference_id: employee_reference_id(employee),
        employee_email: employee.email,
        first_name: dependent.first_name,
        last_name: dependent.last_name,
        relationship: dependent.relationship,
        date_of_birth: dependent.date_of_birth.iso8601,
        status: "active",
        eligibility_status: "eligible"
      }
    end

    def payroll_deduction_payload(resource_id)
      employee = ensure_local_employee
      deduction = @context.fetch(:local_deduction)
      enrollment = @context[:local_enrollment]
      plan = enrollment&.benefit_plan
      {
        id: resource_id,
        employee_id: employee.vitable_id,
        reference_id: employee_reference_id(employee),
        email: employee.email,
        plan_id: plan&.vitable_id,
        enrollment_id: enrollment&.vitable_id,
        benefit_name: plan&.name || deduction.code,
        deduction_amount_in_cents: deduction.amount_cents,
        frequency: "biweekly",
        status: "active"
      }.compact
    end

    def plan_year_payload(resource_id)
      year = Date.current.year
      {
        id: resource_id,
        employer_id: require_context(:employer_id, "remote employer ID"),
        employer_reference_id: "musto_employer_#{ensure_local_employer.id}",
        year:,
        starts_on: Date.new(year, 1, 1).iso8601,
        ends_on: Date.new(year, 12, 31).iso8601,
        open_enrollment_starts_on: Date.new(year - 1, 11, 1).iso8601,
        open_enrollment_ends_on: Date.new(year - 1, 11, 15).iso8601,
        status: "active"
      }
    end

    def page_data(response)
      RemoteCollectionResponseDto
        .from_response(serialize_response(response), response_label: "Vitable certification collection")
        .records
    end

    def sample_id(payload)
      payload.to_h.stringify_keys.fetch("id", nil) if payload.present?
    end

    def serialize_response(response)
      serialized =
        if response.respond_to?(:deep_to_h)
          response.deep_to_h
        elsif response.respond_to?(:to_h)
          response.to_h
        else
          { value: response.to_s }
        end

      PayloadRedactor.redact(serialized.deep_stringify_keys)
    end
  end
end
