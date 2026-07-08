module Vitable
  class RefreshApiSnapshotCommand < ApplicationCommand
    def initialize(dto:, repository: IntegrationRepository.new, gateway_class: ClientGateway)
      @dto = dto
      @repository = repository
      @gateway_class = gateway_class
    end

    def call
      connection = @repository.find_connection(@dto.connection_id)
      sync_run = @repository.create_api_snapshot_run(connection:, requested_by: @dto.requested_by)

      unless connection.credentials_present?
        @repository.mark_connection_needs_credentials(connection)
        sync_run.update!(
          status: "needs_credentials",
          completed_at: Time.current,
          error_message: "#{connection.api_key_reference} is not configured",
          stats: sync_run.stats.to_h.merge("blocked_reason" => "#{connection.api_key_reference} is not configured")
        )
        return failure(record: sync_run, errors: "#{connection.api_key_reference} is not configured")
      end

      snapshot = build_snapshot(connection)
      sync_run = @repository.succeed_api_snapshot_run(connection, sync_run, snapshot)
      success(record: sync_run, value: snapshot)
    rescue VitableConnect::Errors::APIError => e
      @repository.fail_api_snapshot_run(connection, sync_run, e)
      failure(record: sync_run, errors: "#{e.class}: #{e.message}")
    rescue ActiveRecord::RecordInvalid => e
      failure(record: e.record, errors: e.record.errors.full_messages)
    end

    private

    def build_snapshot(connection)
      gateway = @gateway_class.new(connection)
      refreshed_at = Time.current.iso8601
      employers = page_data(gateway.list_all_employers)
      remote_employee_rosters = remote_employee_rosters(gateway, connection)
      employee_reconciliation = RemoteEmployeeSnapshotRepository.new(connection:).reconcile_snapshot(
        snapshot_entries: remote_employee_rosters,
        source: "vitable_api_snapshot",
        refreshed_at:
      )
      employee_enrollments = employee_enrollment_snapshot(gateway, connection)
      enrollment_reconciliation = EnrollmentSnapshotRepository.new(connection:).reconcile_snapshot(
        snapshot_entries: employee_enrollments,
        source: "vitable_api_snapshot",
        refreshed_at:
      )

      {
        "requested_by" => @dto.requested_by,
        "employers" => employers,
        "groups" => page_data(gateway.list_all_groups),
        "plans" => page_data(gateway.list_all_plans),
        "webhook_events" => page_data(gateway.list_all_webhook_events),
        "remote_employee_rosters" => remote_employee_rosters,
        "employee_reconciliation" => employee_reconciliation.to_metadata,
        "employee_enrollments" => employee_enrollments,
        "enrollment_reconciliation" => enrollment_reconciliation.to_metadata
      }
    end

    def remote_employee_rosters(gateway, connection)
      local_remote_employers(connection).map do |employer|
        {
          "local_employer_id" => employer.id,
          "remote_employer_id" => employer.vitable_id,
          "employer_name" => employer.name,
          "employees" => page_data(gateway.list_all_employer_employees(employer.vitable_id))
        }
      rescue VitableConnect::Errors::NotFoundError => e
        {
          "local_employer_id" => employer.id,
          "remote_employer_id" => employer.vitable_id,
          "employer_name" => employer.name,
          "employees" => [],
          "error_class" => e.class.name,
          "error_message" => e.message
        }
      end
    end

    def employee_enrollment_snapshot(gateway, connection)
      local_remote_employees(connection).map do |employee|
        {
          "local_employee_id" => employee.id,
          "remote_employee_id" => employee.vitable_id,
          "employee_name" => employee.full_name,
          "email" => employee.email,
          "enrollments" => page_data(gateway.list_all_employee_enrollments(employee.vitable_id))
        }
      rescue VitableConnect::Errors::NotFoundError => e
        {
          "local_employee_id" => employee.id,
          "remote_employee_id" => employee.vitable_id,
          "employee_name" => employee.full_name,
          "email" => employee.email,
          "error_class" => e.class.name,
          "error_message" => e.message
        }
      end
    end

    def local_remote_employers(connection)
      Employer
        .joins(:organization)
        .where(organization: connection.organization)
        .where.not(vitable_id: [ nil, "" ])
    end

    def local_remote_employees(connection)
      Employer
        .joins(:organization)
        .where(organization: connection.organization)
        .includes(:employees)
        .flat_map(&:employees)
        .select { |employee| employee.vitable_id.present? }
    end

    def page_data(response)
      serialize_response(response).fetch("data", [])
    end

    def serialize_response(response)
      return {} if response.blank?
      return response.deep_to_h.deep_stringify_keys if response.respond_to?(:deep_to_h)
      return response.to_h.deep_stringify_keys if response.respond_to?(:to_h)

      { "value" => response.to_s }
    end
  end
end
