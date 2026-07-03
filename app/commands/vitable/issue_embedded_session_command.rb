module Vitable
  class IssueEmbeddedSessionCommand < ApplicationCommand
    def initialize(dto:, employer_repository: Employers::EmployerRepository.new, gateway_class: ClientGateway)
      @dto = dto
      @employer = employer_repository.first_for_operations
      @repository = EmbeddedSessionsRepository.new(employer: @employer)
      @gateway_class = gateway_class
    end

    def call
      return failure(errors: "No employer is available for embedded enrollment sessions") unless @employer
      return failure(errors: "No Vitable connection is available for embedded enrollment sessions") unless @repository.connection

      employee = @repository.find_employee(@dto.employee_id)
      @repository.generate_packet(requested_by: @dto.requested_by) unless @repository.latest_packet
      sync_run = @repository.create_token_run(employee:, requested_by: @dto.requested_by)

      return blocked(sync_run, "Employee needs a Vitable employee ID before a token can be issued") if employee.vitable_id.blank?
      return blocked(sync_run, "Employee has no pending or accepted enrollment records") if employee.enrollments.none? { |enrollment| enrollment.status.in?(%w[pending accepted]) }

      unless @repository.connection.credentials_present?
        sync_run = @repository.mark_token_needs_credentials(sync_run)
        return failure(record: sync_run, errors: sync_run.error_message)
      end

      response = @gateway_class.new(@repository.connection).issue_employee_access_token(employee.vitable_id)
      sync_run = @repository.mark_token_succeeded(sync_run, response)
      success(record: sync_run, value: response)
    rescue VitableConnect::Errors::APIError => e
      @repository.mark_token_failed(sync_run, e)
      failure(record: sync_run, errors: "#{e.class}: #{e.message}")
    rescue ActiveRecord::RecordInvalid => e
      failure(record: e.record, errors: e.record.errors.full_messages)
    end

    private

    def blocked(sync_run, message)
      sync_run = @repository.mark_token_blocked(sync_run, message)
      failure(record: sync_run, errors: message)
    end
  end
end
