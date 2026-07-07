module Vitable
  class RefreshRemoteRosterCommand < ApplicationCommand
    def initialize(dto:, employer_repository: Employers::EmployerRepository.new, gateway_class: ClientGateway)
      @dto = dto
      @employer = employer_repository.first_for_operations
      @repository = CensusSyncRepository.new(employer: @employer)
      @gateway_class = gateway_class
    end

    def call
      return failure(errors: "No employer is available for Vitable roster refresh") unless @employer
      return failure(errors: "No Vitable connection is available for roster refresh") unless @repository.connection
      return failure(errors: "Remote Vitable employer ID is missing") if @employer.vitable_id.blank?

      sync_run = @repository.create_remote_roster_run(requested_by: @dto.requested_by)

      unless @repository.connection.credentials_present?
        sync_run = @repository.mark_sync_needs_credentials(sync_run)
        return failure(record: sync_run, errors: sync_run.error_message)
      end

      response = @gateway_class.new(@repository.connection).list_all_employer_employees(@employer.vitable_id)
      sync_run = @repository.mark_remote_roster_succeeded(sync_run, response)
      success(record: sync_run, value: response)
    rescue VitableConnect::Errors::APIError => e
      @repository.mark_remote_roster_failed(sync_run, e)
      failure(record: sync_run, errors: "#{e.class}: #{e.message}")
    rescue ActiveRecord::RecordInvalid => e
      failure(record: e.record, errors: e.record.errors.full_messages)
    end
  end
end
