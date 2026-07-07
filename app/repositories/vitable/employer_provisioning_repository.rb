module Vitable
  class EmployerProvisioningRepository < ApplicationRepository
    PACKET_KEY = "vitable_employer_provisioning_packet"
    PROVISIONING_OPERATIONS = %w[employer_create employer_settings_update].freeze
    REQUEST_OPERATIONS = %w[employer.create employer.update_settings].freeze

    def initialize(employer:)
      @employer = employer
    end

    def connection
      @connection ||= vitable_connection_for(@employer&.organization)
    end

    def latest_packet
      @employer&.settings.to_h.fetch(PACKET_KEY, nil)
    end

    def preview_packet(requested_by: "ops_console")
      build_packet(requested_by:)
    end

    def sync_runs(limit: 12)
      return SyncRun.none unless connection

      connection.sync_runs.where(operation: PROVISIONING_OPERATIONS).recent_first.limit(limit)
    end

    def request_logs(limit: 12)
      return ApiRequestLog.none unless connection

      connection.api_request_logs.where(operation: REQUEST_OPERATIONS).recent_first.limit(limit)
    end

    def generate_packet(requested_by:)
      packet = build_packet(requested_by:)
      @employer.update!(settings: @employer.settings.to_h.merge(PACKET_KEY => packet))
      packet
    end

    def create_sync_run(packet:, operation:, requested_by:)
      connection.sync_runs.create!(
        resource_type: "employer",
        operation:,
        status: "running",
        started_at: Time.current,
        stats: sync_stats(packet:, operation:, requested_by:)
      )
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

    def mark_succeeded(sync_run, response, packet:)
      response_hash = serialize_response(response)
      remote_employer_id = extract_remote_employer_id(response_hash)
      synced_at = Time.current.iso8601
      settings = @employer.settings.to_h.merge(
        "vitable_employer_provisioned_at" => synced_at,
        "vitable_employer_provisioning_last_sync" => {
          "synced_at" => synced_at,
          "operation" => sync_run.operation,
          "packet_id" => packet.fetch("packet_id"),
          "mode" => packet.fetch("mode"),
          "remote_employer_id" => remote_employer_id.presence || @employer.vitable_id
        },
        "vitable_pay_frequency" => packet.fetch("settings_payload", {}).fetch("pay_frequency", nil),
        "vitable_eligibility_policy" => local_eligibility_profile(packet, synced_at)
      )
      @employer.update!(vitable_id: remote_employer_id) if remote_employer_id.present? && @employer.vitable_id.blank?
      @employer.update!(settings:)

      sync_run.update!(
        status: "succeeded",
        completed_at: Time.current,
        error_message: nil,
        stats: sync_run.stats.to_h.merge(
          "remote_response" => response_hash,
          "remote_employer_id" => remote_employer_id.presence || @employer.vitable_id,
          "remote_synced_at" => synced_at
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

    private

    def build_packet(requested_by:)
      create_payload = create_payload_for(primary_location)
      settings_payload = { "pay_frequency" => vitable_pay_frequency }
      eligibility_profile = eligibility_profile_for
      mode = @employer.vitable_id.present? ? "update_settings" : "create"
      holdbacks = holdbacks_for(mode:, create_payload:, settings_payload:, eligibility_profile:)
      endpoint = mode == "create" ? "/v1/employers" : "/v1/employers/:employer_id/settings"

      {
        "packet_id" => "vitable_employer_provisioning_#{@employer.id}_#{Time.current.to_i}",
        "generated_at" => Time.current.iso8601,
        "requested_by" => requested_by,
        "employer_id" => @employer.id,
        "remote_employer_id" => @employer.vitable_id,
        "endpoint" => endpoint,
        "mode" => mode,
        "status" => holdbacks.any? ? "blocked" : "ready",
        "totals" => {
          "payload_field_count" => create_payload.except("address").values.compact.count + create_payload.fetch("address", {}).values.compact.count + settings_payload.values.compact.count,
          "missing_field_count" => holdbacks.count,
          "holdback_count" => holdbacks.count
        },
        "create_payload" => create_payload,
        "settings_payload" => settings_payload,
        "eligibility_policy_payload" => eligibility_profile,
        "eligibility_policy_endpoint" => "employer.eligibility_policy_created webhook",
        "eligibility_policy_action" => "local_profile_only",
        "api_payload" => {
          "create" => create_payload,
          "settings" => settings_payload,
          "local_eligibility_profile" => eligibility_profile
        },
        "holdbacks" => holdbacks
      }
    end

    def create_payload_for(location)
      {
        "name" => @employer.name,
        "legal_name" => @employer.legal_name,
        "ein" => @employer.ein,
        "email" => billing_email,
        "phone_number" => phone_number,
        "reference_id" => "musto_employer_#{@employer.id}",
        "address" => address_payload_for(location)
      }.compact
    end

    def address_payload_for(location)
      return {} unless location

      {
        "address_line_1" => location.address_line1,
        "city" => location.city,
        "state" => location.state,
        "zipcode" => location.postal_code
      }.compact
    end

    def eligibility_profile_for
      {
        "classification" => settings.fetch("eligibility_classification", "All").presence,
        "waiting_period" => settings.fetch("eligibility_waiting_period", "1st of the following month").presence
      }.compact
    end

    def holdbacks_for(mode:, create_payload:, settings_payload:, eligibility_profile:)
      holdbacks = []

      if mode == "create"
        required_create_fields(create_payload).each do |field, value|
          next if value.present?

          holdbacks << holdback(field:, reason_code: "missing_required_field", reason: "#{field.to_s.humanize} is required before creating a Vitable employer.")
        end
      end

      if settings_payload.fetch("pay_frequency", nil).blank?
        holdbacks << holdback(field: "pay_frequency", reason_code: "missing_pay_frequency", reason: "Pay frequency is required before Vitable employer settings can be updated.")
      end

      required_eligibility_profile_fields(eligibility_profile).each do |field, value|
        next if value.present?

        holdbacks << holdback(field:, reason_code: "missing_eligibility_profile_field", reason: "#{field.to_s.humanize} is required before the Vitable eligibility profile is ready.")
      end

      holdbacks
    end

    def required_create_fields(create_payload)
      {
        name: create_payload.fetch("name", nil),
        legal_name: create_payload.fetch("legal_name", nil),
        ein: create_payload.fetch("ein", nil),
        billing_email: create_payload.fetch("email", nil),
        address_line_1: create_payload.dig("address", "address_line_1"),
        city: create_payload.dig("address", "city"),
        state: create_payload.dig("address", "state"),
        zipcode: create_payload.dig("address", "zipcode")
      }
    end

    def required_eligibility_profile_fields(eligibility_profile)
      {
        classification: eligibility_profile.fetch("classification", nil),
        waiting_period: eligibility_profile.fetch("waiting_period", nil)
      }
    end

    def holdback(field:, reason_code:, reason:)
      {
        "field" => field.to_s,
        "status" => "blocked",
        "reason_code" => reason_code,
        "reason" => reason
      }
    end

    def primary_location
      locations = @employer.work_locations.order(:id).to_a
      locations.find { |location| !location.remote? && address_complete?(location) } ||
        locations.find { |location| address_complete?(location) } ||
        locations.find { |location| !location.remote? } ||
        locations.first
    end

    def address_complete?(location)
      [ location.address_line1, location.city, location.state, location.postal_code ].all?(&:present?)
    end

    def billing_email
      settings.fetch("billing_email", nil).presence || settings.fetch("benefits_email", nil).presence
    end

    def phone_number
      settings.fetch("phone_number", nil).presence || settings.fetch("billing_phone", nil).presence
    end

    def vitable_pay_frequency
      local_frequency = settings.fetch("pay_frequency", nil).to_s.tr("-", "_")
      {
        "weekly" => "weekly",
        "biweekly" => "bi_weekly",
        "bi_weekly" => "bi_weekly",
        "semimonthly" => "semi_monthly",
        "semi_monthly" => "semi_monthly",
        "monthly" => "monthly"
      }.fetch(local_frequency, local_frequency.presence)
    end

    def settings
      @settings ||= @employer.settings.to_h.stringify_keys
    end

    def sync_stats(packet:, operation:, requested_by:)
      {
        "packet_id" => packet.fetch("packet_id"),
        "requested_by" => requested_by,
        "operation" => operation,
        "mode" => packet.fetch("mode"),
        "resource_id" => @employer.vitable_id.presence || "local_employer_#{@employer.id}",
        "endpoint" => packet.fetch("endpoint"),
        "payload" => packet.fetch("api_payload", {})
      }
    end

    def serialize_response(response)
      return {} if response.blank?
      return response.deep_to_h.deep_stringify_keys if response.respond_to?(:deep_to_h)
      return response.to_h.deep_stringify_keys if response.respond_to?(:to_h)

      { "value" => response.to_s }
    end

    def extract_remote_employer_id(response_hash)
      response_hash.dig("data", "id") ||
        response_hash.dig("data", "employer", "id") ||
        response_hash.fetch("id", nil)
    end

    def local_eligibility_profile(packet, synced_at)
      profile = packet.fetch("eligibility_policy_payload", {}).to_h.stringify_keys
      previous = @employer.settings.to_h.fetch("vitable_eligibility_policy", {}).to_h.stringify_keys

      previous.merge(
        profile.merge(
          "status" => "local_ready",
          "source" => "local_profile",
          "synced_with_employer_at" => synced_at,
          "webhook_event_name" => "employer.eligibility_policy_created"
        )
      ).compact
    end
  end
end
