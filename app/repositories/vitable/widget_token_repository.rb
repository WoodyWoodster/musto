module Vitable
  class WidgetTokenRepository < ApplicationRepository
    OPERATION = "widget_token_broker"

    def initialize(employer:, eligibility_repository: EmployeeEligibilityRepository.new)
      @employer = employer
      @eligibility_repository = eligibility_repository
    end

    def connection
      @connection ||= vitable_connection_for(@employer&.organization)
    end

    def find_employee(id)
      @employer.employees.active.find(id)
    end

    def employee_token_block_reason(employee)
      return "Employee needs a Vitable employee ID before a widget token can be issued" if employee.vitable_id.blank?

      @eligibility_repository.enrollment_token_block_reason(employee)
    end

    def create_token_run(dto:, bound_entity_id:, local_record:)
      connection.sync_runs.create!(
        resource_type: dto.bound_entity_type,
        operation: OPERATION,
        status: "running",
        started_at: Time.current,
        stats: {
          "requested_by" => dto.requested_by,
          "bound_entity" => {
            "type" => dto.bound_entity_type,
            "id" => bound_entity_id
          },
          "local_record" => local_record
        }
      )
    end

    def mark_needs_credentials(sync_run)
      message = "#{connection.api_key_reference} is not configured"
      sync_run.update!(
        status: "needs_credentials",
        completed_at: Time.current,
        error_message: message,
        stats: sync_run.stats.to_h.merge("blocked_reason" => message)
      )
      sync_run
    end

    def mark_blocked(sync_run, message)
      sync_run.update!(
        status: "blocked",
        completed_at: Time.current,
        error_message: message,
        stats: sync_run.stats.to_h.merge("blocked_reason" => message)
      )
      sync_run
    end

    def mark_succeeded(sync_run, response_dto)
      sync_run.update!(
        status: "succeeded",
        completed_at: Time.current,
        error_message: nil,
        stats: sync_run.stats.to_h.merge(
          "delivery" => "http_response",
          "issuance" => response_dto.to_metadata
        )
      )
      sync_run
    end

    def mark_failed(sync_run, error)
      sync_run&.update!(
        status: "failed",
        completed_at: Time.current,
        error_message: error.message,
        stats: sync_run.stats.to_h.merge("error_class" => error.class.name)
      )
      sync_run
    end
  end
end
