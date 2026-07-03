module Compliance
  class NoticeRepository < ApplicationRepository
    PACKET_KEY = "compliance_notice_packet"
    READY_STATUSES = %w[response_ready resolved].freeze

    def initialize(employer: nil)
      @employer = employer
    end

    def notices
      return ComplianceNotice.none unless @employer

      @employer.compliance_notices.includes(:employee).due_first
    end

    def open_notices
      notices.open
    end

    def find_notice(id)
      notices.find(id)
    end

    def latest_packet
      @employer&.settings.to_h.fetch(PACKET_KEY, nil)
    end

    def issues
      notices.flat_map { |notice| issues_for(notice) }
    end

    def acknowledge_notice(notice, acknowledged_by:)
      notice.update!(
        status: "in_review",
        acknowledged_at: Time.current,
        metadata: notice.metadata.to_h.merge(
          "acknowledged_by" => acknowledged_by,
          "acknowledged_from" => "compliance_notice_center",
          "acknowledged_at" => Time.current.iso8601
        )
      )
    end

    def resolve_notice(notice, resolved_by:, resolution_summary:)
      notice.update!(
        status: "resolved",
        resolution_summary: resolution_summary.presence || default_resolution_summary(notice),
        responded_at: notice.responded_at || Time.current,
        resolved_at: Time.current,
        metadata: notice.metadata.to_h.merge(
          "resolved_by" => resolved_by,
          "resolved_from" => "compliance_notice_center",
          "resolved_at" => Time.current.iso8601
        )
      )
    end

    def generate_packet(requested_by:)
      lines = notices.map { |notice| packet_line_for(notice) }
      holdbacks = issues
      ready_lines = lines.select { |line| line.fetch("status").in?(READY_STATUSES) }
      packet = {
        "packet_id" => "compliance_notice_#{@employer.id}_#{Time.current.to_i}",
        "generated_at" => Time.current.iso8601,
        "requested_by" => requested_by,
        "employer_id" => @employer.id,
        "status" => holdbacks.any? ? "needs_review" : "ready",
        "totals" => {
          "notice_count" => lines.count,
          "open_count" => lines.count { |line| !line.fetch("status").in?(%w[resolved archived]) },
          "ready_count" => ready_lines.count,
          "holdback_count" => holdbacks.count,
          "amount_cents" => lines.sum { |line| line.fetch("amount_cents", 0).to_i },
          "jurisdiction_count" => lines.map { |line| line.fetch("jurisdiction") }.uniq.count
        },
        "notices" => lines,
        "holdbacks" => holdbacks
      }

      @employer.update!(settings: @employer.settings.to_h.merge(PACKET_KEY => packet))
      packet
    end

    private

    def packet_line_for(notice)
      {
        "notice_id" => notice.id,
        "employee_id" => notice.employee_id,
        "employee_name" => notice.employee&.full_name,
        "source" => notice.source,
        "notice_type" => notice.notice_type,
        "title" => notice.title,
        "agency_name" => notice.agency_name,
        "jurisdiction" => notice.jurisdiction,
        "reference_number" => notice.reference_number,
        "severity" => notice.severity,
        "status" => notice.status,
        "received_on" => notice.received_on.iso8601,
        "due_on" => notice.due_on.iso8601,
        "amount_cents" => notice.amount_cents,
        "response_owner" => notice.response_owner,
        "response_channel" => notice.response_channel,
        "summary" => notice.summary,
        "resolution_summary" => notice.resolution_summary,
        "acknowledged_at" => notice.acknowledged_at&.iso8601,
        "responded_at" => notice.responded_at&.iso8601,
        "resolved_at" => notice.resolved_at&.iso8601
      }
    end

    def issues_for(notice)
      issues = []
      issues << issue(notice, "notice_overdue", "critical", "overdue", "Notice due date has passed.") if notice.overdue?
      issues << issue(notice, "notice_due_soon", "medium", "due_soon", "Notice response is due within 10 days.") if notice.due_soon? && !notice.overdue?
      issues << issue(notice, "unacknowledged_notice", "medium", "received", "Notice has not been acknowledged by the response owner.") if notice.status == "received"
      issues << issue(notice, "missing_reference", "low", "needs_review", "Agency reference number is missing from the notice record.") if notice.reference_number.blank?
      issues << issue(notice, "amount_at_risk", "high", "needs_review", "Notice has an amount at risk that needs finance review.") if notice.amount_cents.positive? && notice.open?
      issues
    end

    def issue(notice, reason_code, severity, status, reason)
      {
        "notice_id" => notice.id,
        "title" => notice.title,
        "agency_name" => notice.agency_name,
        "jurisdiction" => notice.jurisdiction,
        "notice_type" => notice.notice_type,
        "severity" => severity,
        "status" => status,
        "reason_code" => reason_code,
        "reason" => reason,
        "response_owner" => notice.response_owner,
        "due_on" => notice.due_on.iso8601
      }
    end

    def default_resolution_summary(notice)
      "Response retained for #{notice.agency_name} notice #{notice.reference_number.presence || notice.id}."
    end
  end
end
