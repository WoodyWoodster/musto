module Taxes
  class AgencyRegistrationRepository < ApplicationRepository
    PACKET_KEY = "tax_agency_registration_packet"
    REVIEW_STATUSES = %w[draft needs_review blocked].freeze
    READY_STATUSES = %w[submitted registered].freeze

    def initialize(employer: nil)
      @employer = employer
    end

    def registrations
      return TaxAgencyRegistration.none unless @employer

      @employer.tax_agency_registrations.includes(:work_location).due_first
    end

    def find_registration(id)
      registrations.find(id)
    end

    def latest_packet
      @employer&.settings.to_h.fetch(PACKET_KEY, nil)
    end

    def issues
      registrations.flat_map { |registration| issues_for(registration) }
    end

    def submit_registration(registration, submitted_by:, confirmation_number: nil)
      registration.update!(
        status: "submitted",
        submitted_at: Time.current,
        confirmation_number: confirmation_number.presence || generated_confirmation_number(registration),
        metadata: registration.metadata.to_h.merge(
          "submitted_by" => submitted_by,
          "submitted_from" => "tax_agency_registration_center",
          "submitted_at" => Time.current.iso8601
        )
      )
    end

    def generate_packet(requested_by:)
      lines = registrations.map { |registration| packet_line_for(registration) }
      holdbacks = issues
      ready_lines = lines.select { |line| line.fetch("status").in?(READY_STATUSES) }
      packet = {
        "packet_id" => "tax_registration_#{@employer.id}_#{Time.current.to_i}",
        "generated_at" => Time.current.iso8601,
        "requested_by" => requested_by,
        "employer_id" => @employer.id,
        "status" => holdbacks.any? ? "needs_review" : "ready",
        "totals" => {
          "registration_count" => lines.count,
          "ready_count" => ready_lines.count,
          "submitted_count" => lines.count { |line| line.fetch("status") == "submitted" },
          "registered_count" => lines.count { |line| line.fetch("status") == "registered" },
          "holdback_count" => holdbacks.count,
          "jurisdiction_count" => lines.map { |line| line.fetch("jurisdiction") }.uniq.count
        },
        "registrations" => lines,
        "holdbacks" => holdbacks
      }

      @employer.update!(settings: @employer.settings.to_h.merge(PACKET_KEY => packet))
      packet
    end

    private

    def packet_line_for(registration)
      {
        "registration_id" => registration.id,
        "agency_name" => registration.agency_name,
        "jurisdiction" => registration.jurisdiction,
        "registration_type" => registration.registration_type,
        "account_number" => registration.account_number,
        "deposit_schedule" => registration.deposit_schedule,
        "status" => registration.status,
        "risk_level" => registration.risk_level,
        "due_on" => registration.due_on.iso8601,
        "submitted_at" => registration.submitted_at&.iso8601,
        "confirmed_at" => registration.confirmed_at&.iso8601,
        "confirmation_number" => registration.confirmation_number,
        "next_deposit_due_on" => registration.next_deposit_due_on&.iso8601,
        "owner" => registration.owner,
        "location_name" => registration.work_location&.name,
        "notes" => registration.notes
      }
    end

    def issues_for(registration)
      issues = []
      issues << issue(registration, "registration_overdue", "high", "overdue", "Registration due date has passed.") if registration.overdue?
      issues << issue(registration, "registration_due_soon", "medium", "due_soon", "Registration is due within 14 days.") if registration.due_soon? && !registration.overdue?
      issues << issue(registration, "blocked_registration", "high", "blocked", "Registration is blocked and needs payroll tax review.") if registration.blocked?
      issues << issue(registration, "missing_account_number", "medium", "needs_review", "Account number is missing for a submitted registration.") if registration.submitted? && registration.account_number.blank?
      issues << issue(registration, "missing_confirmation", "medium", "needs_review", "Submission confirmation should be retained for audit evidence.") if registration.submitted? && registration.confirmation_number.blank?
      issues << issue(registration, "remote_jurisdiction_review", "medium", "needs_review", "Remote workforce registration needs jurisdiction confirmation.") if remote_jurisdiction_review?(registration)
      issues
    end

    def issue(registration, reason_code, severity, status, reason)
      {
        "registration_id" => registration.id,
        "agency_name" => registration.agency_name,
        "jurisdiction" => registration.jurisdiction,
        "registration_type" => registration.registration_type,
        "severity" => severity,
        "status" => status,
        "reason_code" => reason_code,
        "reason" => reason,
        "owner" => registration.owner,
        "due_on" => registration.due_on.iso8601
      }
    end

    def remote_jurisdiction_review?(registration)
      registration.work_location&.remote? && registration.status.in?(REVIEW_STATUSES)
    end

    def generated_confirmation_number(registration)
      "TAX-#{registration.jurisdiction.parameterize.upcase}-#{registration.id}-#{Time.current.strftime('%Y%m%d')}"
    end
  end
end
