require "vitable_connect"

module Vitable
  class RunDemoSmokeCheckCommand < ApplicationCommand
    def initialize(dto:, repository: IntegrationRepository.new, gateway_class: ClientGateway)
      @dto = dto
      @repository = repository
      @gateway_class = gateway_class
    end

    def call
      connection = smoke_connection
      sync_run = @repository.create_demo_smoke_run(connection:, requested_by: @dto.requested_by)

      unless connection.credentials_present?
        sync_run = @repository.mark_demo_smoke_needs_credentials(sync_run)
        return failure(record: sync_run, errors: sync_run.error_message)
      end

      result = run_read_checks(connection)
      sync_run = @repository.succeed_demo_smoke_run(connection, sync_run, result)
      success(record: sync_run, value: result)
    rescue VitableConnect::Errors::APIError => e
      @repository.fail_demo_smoke_run(sync_run, e)
      failure(record: sync_run, errors: "#{e.class}: #{e.message}")
    rescue ActiveRecord::RecordInvalid => e
      failure(record: e.record, errors: e.record.errors.full_messages)
    end

    private

    def smoke_connection
      if @dto.connection_id.present?
        @repository.find_connection(@dto.connection_id)
      else
        @repository.demo_smoke_connection(environment: @dto.environment, api_key_reference: @dto.api_key_reference)
      end
    end

    def run_read_checks(connection)
      gateway = @gateway_class.new(connection)
      checked_at = Time.current
      auth_response = gateway.issue_access_token
      employers = page_data(gateway.list_all_employers)
      groups = page_data(gateway.list_all_groups)
      plans = page_data(gateway.list_all_plans)
      webhook_events = page_data(gateway.list_all_webhook_events)
      employees = employer_employees(gateway, employers.first)
      enrollments = employee_enrollments(gateway, employees.first)
      retrieved_employer = retrieve_sample(gateway, :retrieve_employer, employers.first)
      retrieved_group = retrieve_sample(gateway, :retrieve_group, groups.first)

      DemoSmokeCheckResultDto.new(
        environment: connection.environment,
        base_url: connection.effective_api_base_url || "https://api.vitablehealth.com",
        checked_at:,
        sdk_version: VitableConnect::VERSION,
        checks: checks_for(auth_response:, employers:, groups:, plans:, webhook_events:, employees:, enrollments:, retrieved_employer:, retrieved_group:),
        counts: {
          "employers" => employers.count,
          "groups" => groups.count,
          "plans" => plans.count,
          "webhook_events" => webhook_events.count,
          "employees" => employees.count,
          "employee_enrollments" => enrollments.count
        },
        samples: {
          "employer_id" => sample_id(employers.first),
          "group_id" => sample_id(groups.first),
          "plan_id" => sample_id(plans.first),
          "webhook_event_id" => sample_id(webhook_events.first),
          "employee_id" => sample_id(employees.first),
          "enrollment_id" => sample_id(enrollments.first)
        }.compact,
        warnings: warnings_for(plans:, employees:, enrollments:)
      )
    end

    def employer_employees(gateway, employer)
      return [] unless sample_id(employer)

      page_data(gateway.list_all_employer_employees(sample_id(employer)))
    rescue VitableConnect::Errors::NotFoundError
      []
    end

    def employee_enrollments(gateway, employee)
      return [] unless sample_id(employee)

      page_data(gateway.list_all_employee_enrollments(sample_id(employee)))
    rescue VitableConnect::Errors::NotFoundError
      []
    end

    def retrieve_sample(gateway, method_name, sample)
      return false unless sample_id(sample)

      gateway.public_send(method_name, sample_id(sample)).present?
    rescue VitableConnect::Errors::NotFoundError
      false
    end

    def checks_for(auth_response:, employers:, groups:, plans:, webhook_events:, employees:, enrollments:, retrieved_employer:, retrieved_group:)
      [
        check("auth.issue_access_token", token_issued?(auth_response)),
        check("employer.list", true, count: employers.count),
        check("employer.retrieve", retrieved_employer, skipped: employers.empty?),
        check("employer.list_employees", true, count: employees.count, skipped: employers.empty?),
        check("employee.list_enrollments", true, count: enrollments.count, skipped: employees.empty?),
        check("group.list", true, count: groups.count),
        check("group.retrieve", retrieved_group, skipped: groups.empty?),
        check("plan.list", true, count: plans.count),
        check("webhook_event.list", true, count: webhook_events.count)
      ]
    end

    def check(name, passed, count: nil, skipped: false)
      {
        "name" => name,
        "status" => skipped ? "skipped" : (passed ? "ready" : "failed"),
        "count" => count
      }.compact
    end

    def warnings_for(plans:, employees:, enrollments:)
      [
        ("Vitable demo returned zero plans; member sync remains blocked until remote plan IDs are available." if plans.empty?),
        ("No remote employees were available to sample enrollment reads." if employees.empty?),
        ("No remote employee enrollments were available in the demo sample." if employees.any? && enrollments.empty?)
      ].compact
    end

    def page_data(response)
      serialized = serialize_response(response)
      serialized.fetch("data", []).map { |entry| entry.to_h.stringify_keys }
    end

    def sample_id(payload)
      payload.to_h.stringify_keys.fetch("id", nil) if payload.present?
    end

    def token_issued?(response)
      serialized = serialize_response(response)
      serialized.fetch("access_token", nil).present? || serialized.dig("data", "access_token").present?
    end

    def serialize_response(response)
      return {} if response.blank?
      return response.deep_to_h.deep_stringify_keys if response.respond_to?(:deep_to_h)
      return response.to_h.deep_stringify_keys if response.respond_to?(:to_h)

      { "value" => response.to_s }
    end
  end
end
