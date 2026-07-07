module Vitable
  class SubmitCareGroupCommand < ApplicationCommand
    def initialize(dto:, employer_repository: Employers::EmployerRepository.new, gateway_class: ClientGateway)
      @dto = dto
      @employer = employer_repository.first_for_operations
      @repository = CareGroupRepository.new(employer: @employer)
      @gateway_class = gateway_class
    end

    def call
      return failure(errors: "No employer is available for Vitable care group setup") unless @employer
      return failure(errors: "No Vitable connection is available for care group setup") unless @repository.connection

      packet = @repository.latest_group_packet || @repository.generate_group_packet(requested_by: @dto.requested_by)
      sync_run = @repository.create_group_run(packet:, requested_by: @dto.requested_by)

      return blocked(sync_run, "Resolve care group packet holdbacks before submitting") if packet.fetch("status") == "blocked"

      unless @repository.connection.credentials_present?
        sync_run = @repository.mark_needs_credentials(sync_run)
        return failure(record: sync_run, value: packet, errors: sync_run.error_message)
      end

      response = submit_packet(packet)
      sync_run = @repository.mark_group_succeeded(sync_run, response, packet:)
      success(record: sync_run, value: response)
    rescue VitableConnect::Errors::APIError => e
      @repository.mark_failed(sync_run, e)
      failure(record: sync_run, errors: "#{e.class}: #{e.message}")
    rescue ActiveRecord::RecordInvalid => e
      failure(record: e.record, errors: e.record.errors.full_messages)
    end

    private

    def submit_packet(packet)
      gateway = @gateway_class.new(@repository.connection)
      return gateway.create_group(packet.fetch("api_payload")) if packet.fetch("mode") == "create"

      gateway.update_group(@repository.remote_group_id, packet.fetch("api_payload"))
    end

    def blocked(sync_run, message)
      sync_run = @repository.mark_blocked(sync_run, message)
      failure(record: sync_run, value: @repository.latest_group_packet, errors: message)
    end
  end
end
