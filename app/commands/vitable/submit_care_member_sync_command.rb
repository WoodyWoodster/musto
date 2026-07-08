module Vitable
  class SubmitCareMemberSyncCommand < ApplicationCommand
    def initialize(dto:, employer_repository: Employers::EmployerRepository.new, gateway_class: ClientGateway)
      @dto = dto
      @employer = employer_repository.first_for_operations
      @repository = CareGroupRepository.new(employer: @employer)
      @gateway_class = gateway_class
    end

    def call
      response = nil
      return failure(errors: "No employer is available for Vitable care member sync") unless @employer
      return failure(errors: "No Vitable connection is available for care member sync") unless @repository.connection

      manifest = @repository.latest_member_manifest || @repository.generate_member_manifest(requested_by: @dto.requested_by)
      sync_run = @repository.create_member_sync_run(manifest:, requested_by: @dto.requested_by)

      return blocked(sync_run, "Remote Vitable care group ID is missing") if @repository.remote_group_id.blank?
      return blocked(sync_run, "Resolve care member manifest holdbacks before submitting Vitable member sync") if manifest_holdbacks(manifest).any?
      return blocked(sync_run, "Generate at least one ready care member before submitting member sync") if ready_members(manifest).empty?

      unless @repository.connection.credentials_present?
        sync_run = @repository.mark_needs_credentials(sync_run)
        return failure(record: sync_run, value: manifest, errors: sync_run.error_message)
      end

      response = @gateway_class.new(@repository.connection).submit_group_member_sync(@repository.remote_group_id, ready_members(manifest))
      sync_run = @repository.mark_member_sync_succeeded(sync_run, response)
      success(record: sync_run, value: response)
    rescue VitableConnect::Errors::APIError => e
      @repository.mark_failed(sync_run, e)
      failure(record: sync_run, errors: PayloadRedactor.error_with_class(e))
    rescue ArgumentError => e
      @repository.mark_failed(sync_run, e, response:)
      failure(record: sync_run, errors: PayloadRedactor.error_message(e))
    rescue ActiveRecord::RecordInvalid => e
      failure(record: e.record, errors: e.record.errors.full_messages)
    end

    private

    def ready_members(manifest)
      manifest.fetch("api_payload", {}).fetch("members", [])
    end

    def manifest_holdbacks(manifest)
      Array(manifest.fetch("holdbacks", []))
    end

    def blocked(sync_run, message)
      sync_run = @repository.mark_blocked(sync_run, message)
      failure(record: sync_run, value: @repository.latest_member_manifest, errors: message)
    end
  end
end
