module Vitable
  class IssueWidgetTokenCommand < ApplicationCommand
    def initialize(dto:, employer_repository: Employers::EmployerRepository.new, gateway_class: ClientGateway)
      @dto = dto
      @employer = employer_repository.first_for_operations
      @repository = WidgetTokenRepository.new(employer: @employer)
      @gateway_class = gateway_class
    end

    def call
      return failure(errors: "No employer is available for Vitable widget tokens") unless @employer
      return failure(errors: "No Vitable connection is available for widget tokens") unless @repository.connection

      context = token_context
      sync_run = @repository.create_token_run(dto: @dto, bound_entity_id: context.fetch(:remote_id), local_record: context.fetch(:local_record))
      return blocked(sync_run, context.fetch(:blocked_reason)) if context.fetch(:blocked_reason, nil).present?

      unless @repository.connection.credentials_present?
        sync_run = @repository.mark_needs_credentials(sync_run)
        return failure(record: sync_run, errors: sync_run.error_message)
      end

      response = issue_token(context.fetch(:remote_id))
      response_dto = WidgetTokenResponseDto.from_response(serialize_response(response), issued_at: Time.current)
      sync_run = @repository.mark_succeeded(sync_run, response_dto)
      success(record: sync_run, value: response_dto)
    rescue ::VitableConnect::Errors::APIError => e
      @repository.mark_failed(sync_run, e)
      failure(record: sync_run, errors: "#{e.class}: #{e.message}")
    rescue ActiveRecord::RecordNotFound
      failure(errors: "Employee is not available for Vitable widget token issuance")
    rescue ActiveRecord::RecordInvalid => e
      failure(record: e.record, errors: e.record.errors.full_messages)
    end

    private

    def token_context
      case @dto.bound_entity_type
      when "employer"
        {
          remote_id: @employer.vitable_id,
          local_record: { "type" => "employer", "id" => @employer.id, "name" => @employer.name },
          blocked_reason: @employer.vitable_id.blank? ? "Employer needs a Vitable employer ID before a widget token can be issued" : nil
        }
      when "employee"
        employee = @repository.find_employee(@dto.employee_id)
        {
          remote_id: employee.vitable_id,
          local_record: { "type" => "employee", "id" => employee.id, "name" => employee.full_name },
          blocked_reason: employee.vitable_id.blank? ? "Employee needs a Vitable employee ID before a widget token can be issued" : nil
        }
      else
        raise ArgumentError, "Unsupported widget token entity: #{@dto.bound_entity_type}"
      end
    end

    def issue_token(remote_id)
      gateway = @gateway_class.new(@repository.connection)

      if @dto.bound_entity_type == "employer"
        gateway.issue_employer_access_token(remote_id)
      else
        gateway.issue_employee_access_token(remote_id)
      end
    end

    def serialize_response(response)
      return {} if response.blank?
      return response.deep_to_h.deep_stringify_keys if response.respond_to?(:deep_to_h)
      return response.to_h.deep_stringify_keys if response.respond_to?(:to_h)

      { "value" => response.to_s }
    end

    def blocked(sync_run, message)
      sync_run = @repository.mark_blocked(sync_run, message)
      failure(record: sync_run, errors: message)
    end
  end
end
