module Vitable
  class IssueAdminSessionCommand < ApplicationCommand
    def initialize(dto:, employer_repository: Employers::EmployerRepository.new, gateway_class: ClientGateway)
      @dto = dto
      @employer = employer_repository.first_for_operations
      @repository = AdminSessionsRepository.new(employer: @employer)
      @gateway_class = gateway_class
    end

    def call
      response = nil
      return failure(errors: "No employer is available for employer admin sessions") unless @employer
      return failure(errors: "No Vitable connection is available for employer admin sessions") unless @repository.connection

      @repository.generate_packet(requested_by: @dto.requested_by) unless @repository.latest_packet
      sync_run = @repository.create_token_run(requested_by: @dto.requested_by)

      return blocked(sync_run, "Employer needs a Vitable employer ID before an admin token can be issued") if @employer.vitable_id.blank?

      unless @repository.connection.credentials_present?
        sync_run = @repository.mark_token_needs_credentials(sync_run)
        return failure(record: sync_run, errors: sync_run.error_message)
      end

      response = @gateway_class.new(@repository.connection).issue_employer_access_token(@employer.vitable_id)
      sync_run = @repository.mark_token_succeeded(sync_run, response)
      success(record: sync_run, value: response)
    rescue ::VitableConnect::Errors::APIError => e
      @repository.mark_token_failed(sync_run, e)
      failure(record: sync_run, errors: "#{e.class}: #{e.message}")
    rescue ArgumentError => e
      @repository.mark_token_failed(sync_run, e, response:)
      failure(record: sync_run, errors: e.message)
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
