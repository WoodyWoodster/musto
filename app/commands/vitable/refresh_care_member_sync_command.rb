module Vitable
  class RefreshCareMemberSyncCommand < ApplicationCommand
    def initialize(dto:, employer_repository: Employers::EmployerRepository.new, gateway_class: ClientGateway)
      @dto = dto
      @employer = employer_repository.first_for_operations
      @repository = CareGroupRepository.new(employer: @employer)
      @gateway_class = gateway_class
    end

    def call
      return failure(errors: "No employer is available for Vitable care member sync") unless @employer
      return failure(errors: "No Vitable connection is available for care member sync") unless @repository.connection

      sync_run = @repository.create_member_sync_refresh_run(requested_by: @dto.requested_by)
      request_id = @repository.latest_member_sync_request.to_h.fetch("request_id", nil)

      return blocked(sync_run, "Remote Vitable care group ID is missing") if @repository.remote_group_id.blank?
      return blocked(sync_run, "No care member sync request is available to refresh") if request_id.blank?

      unless @repository.connection.credentials_present?
        sync_run = @repository.mark_needs_credentials(sync_run)
        return failure(record: sync_run, errors: sync_run.error_message)
      end

      response = @gateway_class.new(@repository.connection).retrieve_group_member_sync(@repository.remote_group_id, request_id)
      sync_run = @repository.mark_member_sync_refresh_succeeded(sync_run, response)
      success(record: sync_run, value: response)
    rescue VitableConnect::Errors::APIError => e
      @repository.mark_failed(sync_run, e)
      failure(record: sync_run, errors: "#{e.class}: #{e.message}")
    rescue ArgumentError => e
      @repository.mark_failed(sync_run, e)
      failure(record: sync_run, errors: e.message)
    rescue ActiveRecord::RecordInvalid => e
      failure(record: e.record, errors: e.record.errors.full_messages)
    end

    private

    def blocked(sync_run, message)
      sync_run = @repository.mark_blocked(sync_run, message)
      failure(record: sync_run, errors: message)
    end
  end
end
