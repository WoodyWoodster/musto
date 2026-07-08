module Vitable
  class AdminSessionsRepository < ApplicationRepository
    PACKET_KEY = "vitable_admin_sessions_packet"
    SESSION_KEY = "vitable_admin_session"
    TOKEN_OPERATION = "embedded_admin_token"
    TOKEN_LOG_OPERATION = "auth.issue_employer_access_token"
    WIDGETS = [
      {
        "key" => "benefits",
        "name" => "Employer benefits",
        "component" => "EmployerBenefitsWidget",
        "description" => "Benefits administration dashboard for enrollments and coverage."
      },
      {
        "key" => "billing",
        "name" => "Employer billing",
        "component" => "EmployerBillingWidget",
        "description" => "Billing dashboard for invoices, payments, and billing history."
      }
    ].freeze

    def initialize(employer:)
      @employer = employer
    end

    def connection
      @connection ||= vitable_connection_for(@employer&.organization)
    end

    def latest_packet
      @employer&.settings.to_h.fetch(PACKET_KEY, nil)
    end

    def latest_issuance
      AdminSessionIssuanceDto.from_hash(@employer&.settings.to_h.fetch(SESSION_KEY, {}))
    end

    def token_runs(limit: 12)
      return SyncRun.none unless connection

      connection.sync_runs.where(operation: TOKEN_OPERATION).recent_first.limit(limit)
    end

    def request_logs(limit: 12)
      return ApiRequestLog.none unless connection

      connection.api_request_logs.where(operation: TOKEN_LOG_OPERATION).recent_first.limit(limit)
    end

    def generate_packet(requested_by:)
      holdbacks = holdbacks_for
      packet = {
        "packet_id" => "vitable_admin_sessions_#{@employer.id}_#{Time.current.to_i}",
        "generated_at" => Time.current.iso8601,
        "requested_by" => requested_by,
        "employer_id" => @employer.id,
        "remote_employer_id" => @employer.vitable_id,
        "status" => holdbacks.any? ? "blocked" : "ready",
        "totals" => {
          "widget_count" => WIDGETS.count,
          "holdback_count" => holdbacks.count
        },
        "token_request" => {
          "grant_type" => "client_credentials",
          "bound_entity_type" => "employer",
          "endpoint" => "/v1/auth/access-tokens",
          "authorization_header" => WidgetLaunchToken::HEADER
        },
        "launch_authorization" => launch_authorization,
        "widgets" => WIDGETS.map { |widget| widget.merge("status" => holdbacks.any? ? "blocked" : "ready") },
        "holdbacks" => holdbacks
      }

      @employer.update!(settings: @employer.settings.to_h.merge(PACKET_KEY => packet))
      packet
    end

    def create_token_run(requested_by:)
      packet = latest_packet || generate_packet(requested_by:)

      connection.sync_runs.create!(
        resource_type: "employer",
        operation: TOKEN_OPERATION,
        status: "running",
        started_at: Time.current,
        stats: {
          "requested_by" => requested_by,
          "packet_id" => packet.fetch("packet_id"),
          "employer_id" => @employer.id,
          "employer_name" => @employer.name,
          "remote_employer_id" => @employer.vitable_id,
          "widgets" => packet.fetch("widgets", []),
          "bound_entity" => {
            "type" => "employer",
            "id" => @employer.vitable_id
          }
        }
      )
    end

    def mark_token_blocked(sync_run, message)
      sync_run.update!(
        status: "blocked",
        completed_at: Time.current,
        error_message: message,
        stats: sync_run.stats.to_h.merge("blocked_reason" => message)
      )
      sync_run
    end

    def mark_token_needs_credentials(sync_run)
      message = "#{connection.api_key_reference} is not configured"
      sync_run.update!(
        status: "needs_credentials",
        completed_at: Time.current,
        error_message: message,
        stats: sync_run.stats.to_h.merge("blocked_reason" => message)
      )
      sync_run
    end

    def mark_token_succeeded(sync_run, response)
      issued_at = Time.current
      response_hash = serialize_response(response)
      issuance = AdminSessionIssuanceDto.from_response(response_hash, issued_at:, sync_run_id: sync_run.id)
      raise ArgumentError, "Vitable admin token response did not include an access token" unless issuance.token_present

      persist_issuance(issuance)

      sync_run.update!(
        status: "succeeded",
        completed_at: issued_at,
        error_message: nil,
        stats: sync_run.stats.to_h.merge(
          "token_response" => token_summary(response_hash),
          "issuance" => issuance.to_metadata
        )
      )
      sync_run
    end

    def mark_token_failed(sync_run, error)
      sync_run&.update!(
        status: "failed",
        completed_at: Time.current,
        error_message: error.message,
        stats: sync_run.stats.to_h.merge("error_class" => error.class.name)
      )
      sync_run
    end

    private

    def holdbacks_for
      holdbacks = []
      if @employer.vitable_id.blank?
        holdbacks << {
          "field" => "remote_employer_id",
          "status" => "blocked",
          "reason_code" => "missing_remote_employer",
          "reason" => "Create or reconcile the Vitable employer before issuing employer-bound admin tokens."
        }
      end

      holdbacks
    end

    def launch_authorization
      expires_at = WidgetLaunchToken.expires_at

      {
        "type" => "signed_launch_token",
        "header" => WidgetLaunchToken::HEADER,
        "expires_at" => expires_at.iso8601,
        "token" => WidgetLaunchToken.issue(scope: "employer", employer_id: @employer.id, expires_at:)
      }
    end

    def persist_issuance(issuance)
      session_metadata = issuance.to_metadata
      settings = @employer.settings.to_h.stringify_keys.merge(SESSION_KEY => session_metadata)
      packet = settings.fetch(PACKET_KEY, {}).to_h.deep_dup

      if packet.present?
        packet["status"] = "session_issued"
        packet["latest_session"] = session_metadata
        packet["widgets"] = packet.fetch("widgets", []).map do |widget|
          widget.to_h.stringify_keys.merge("status" => "session_issued")
        end
        settings[PACKET_KEY] = packet
      end

      @employer.update!(settings:)
    end

    def token_summary(response)
      PayloadRedactor.redact(response.to_h.deep_stringify_keys)
    end

    def serialize_response(response)
      return {} if response.blank?
      return response.deep_to_h.deep_stringify_keys if response.respond_to?(:deep_to_h)
      return response.to_h.deep_stringify_keys if response.respond_to?(:to_h)

      { "value" => response.to_s }
    end
  end
end
