module Vitable
  class SubmitEmployerProvisioningCommand < ApplicationCommand
    def initialize(dto:, employer_repository: Employers::EmployerRepository.new, gateway_class: ClientGateway)
      @dto = dto
      @employer = employer_repository.first_for_operations
      @repository = EmployerProvisioningRepository.new(employer: @employer)
      @gateway_class = gateway_class
    end

    def call
      return failure(errors: "No employer is available for Vitable employer provisioning") unless @employer
      return failure(errors: "No Vitable connection is available for employer provisioning") unless @repository.connection

      packet = @repository.latest_packet || @repository.generate_packet(requested_by: @dto.requested_by)
      operation = packet.fetch("mode") == "create" ? "employer_create" : "employer_settings_update"
      sync_run = @repository.create_sync_run(packet:, operation:, requested_by: @dto.requested_by)

      return blocked(sync_run, "Resolve provisioning packet holdbacks before submitting") if packet.fetch("status") == "blocked"

      unless @repository.connection.credentials_present?
        sync_run = @repository.mark_needs_credentials(sync_run)
        return failure(record: sync_run, value: packet, errors: sync_run.error_message)
      end

      response = submit_packet(packet)
      sync_run = @repository.mark_succeeded(sync_run, response, packet:)
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

      if packet.fetch("mode") == "create"
        employer_response = gateway.create_employer(packet.fetch("create_payload"))
        remote_employer_id = remote_employer_id_from(employer_response) || @employer.vitable_id
        @employer.update!(vitable_id: remote_employer_id) if remote_employer_id.present? && @employer.vitable_id.blank?
        employer_response
      else
        gateway.update_employer_settings(@employer.vitable_id, packet.fetch("settings_payload").fetch("pay_frequency"))
      end
    end

    def remote_employer_id_from(response)
      response_hash = serialize_response(response)
      response_hash.dig("data", "id") ||
        response_hash.dig("data", "employer", "id") ||
        response_hash.fetch("id", nil)
    end

    def serialize_response(response)
      return {} if response.blank?
      return response.deep_to_h.deep_stringify_keys if response.respond_to?(:deep_to_h)
      return response.to_h.deep_stringify_keys if response.respond_to?(:to_h)

      { "value" => response.to_s }
    end

    def blocked(sync_run, message)
      sync_run = @repository.mark_blocked(sync_run, message)
      failure(record: sync_run, value: @repository.latest_packet, errors: message)
    end
  end
end
