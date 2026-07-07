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
      eligibility_policy_response = nil

      if packet.fetch("mode") == "create"
        employer_response = gateway.create_employer(packet.fetch("create_payload"))
        remote_employer_id = remote_employer_id_from(employer_response) || @employer.vitable_id
        @employer.update!(vitable_id: remote_employer_id) if remote_employer_id.present? && @employer.vitable_id.blank?
        eligibility_policy_response = create_eligibility_policy_if_needed(gateway, remote_employer_id, packet)
        combined_response(employer_response, eligibility_policy_response)
      else
        settings_response = gateway.update_employer_settings(@employer.vitable_id, packet.fetch("settings_payload").fetch("pay_frequency"))
        eligibility_policy_response = create_eligibility_policy_if_needed(gateway, @employer.vitable_id, packet)
        combined_response(settings_response, eligibility_policy_response)
      end
    end

    def create_eligibility_policy_if_needed(gateway, employer_id, packet)
      return if employer_id.blank?
      return if packet.fetch("eligibility_policy_action", "create") == "skip_existing"

      gateway.create_eligibility_policy(employer_id, packet.fetch("eligibility_policy_payload"))
    rescue VitableConnect::Errors::NotFoundError => e
      raise unless @repository.connection.effective_api_base_url == IntegrationConnection::DEMO_BASE_URL

      {
        status: "endpoint_unavailable",
        endpoint: "/v1/employers/#{employer_id}/benefit-eligibility-policies",
        message: "Vitable demo returned 404 for eligibility policy creation.",
        error_class: e.class.name
      }
    end

    def combined_response(primary_response, eligibility_policy_response)
      primary_hash = serialize_response(primary_response)
      eligibility_policy_hash = serialize_response(eligibility_policy_response)
      data = primary_hash.fetch("data", primary_hash).merge("eligibility_policy" => eligibility_policy_hash.presence)

      { "data" => data.compact }
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
