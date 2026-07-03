module Compensation
  class ChangesRepository < ApplicationRepository
    PACKET_KEY = "compensation_change_packet"

    def initialize(employer: nil)
      @employer = employer
    end

    def changes
      return CompensationChange.none unless @employer

      @employer
        .compensation_changes
        .includes(:payroll_run, employee: [ :department, :work_location ])
        .recent_first
    end

    def find_change(id)
      changes.find(id)
    end

    def payroll_run
      return unless @employer

      @payroll_run ||= @employer.payroll_runs.where("pay_date >= ?", Date.current).order(:pay_date).first ||
        @employer.payroll_runs.order(pay_date: :desc).first
    end

    def packets
      payload = @employer&.settings.to_h.fetch(PACKET_KEY, nil)
      payload.present? ? [ payload ] : []
    end

    def approve_change(change, approved_by:)
      return false unless change.approvable?

      now = Time.current
      change.update!(
        status: "approved",
        submitted_at: change.submitted_at || now,
        submitted_by: change.submitted_by.presence || approved_by,
        approved_by:,
        approved_at: now,
        metadata: change.metadata.to_h.merge(
          "approved_by" => approved_by,
          "approved_at" => now.iso8601
        )
      )
    end

    def reject_change(change, reviewed_by:, reason:)
      return false if change.applied?

      now = Time.current
      change.update!(
        status: "rejected",
        rejected_by: reviewed_by,
        rejected_at: now,
        rejection_reason: reason,
        metadata: change.metadata.to_h.merge(
          "rejected_by" => reviewed_by,
          "rejected_at" => now.iso8601,
          "rejection_reason" => reason
        )
      )
    end

    def apply_change(change, applied_by:)
      return false unless change.approved?

      CompensationChange.transaction do
        run = change.payroll_run || payroll_run
        apply_pay_change(change, run:)
        now = Time.current
        change.update!(
          status: "applied",
          payroll_run: run,
          applied_by:,
          applied_at: now,
          metadata: change.metadata.to_h.merge(
            "applied_by" => applied_by,
            "applied_at" => now.iso8601,
            "payroll_run_id" => run&.id
          )
        )
      end
    end

    def generate_packet(requested_by:)
      approved_changes = changes.approved.not_applied.to_a
      holdbacks = change_holdbacks
      lines = approved_changes.map { |change| packet_line(change) }
      holdbacks << empty_holdback("No approved compensation changes are ready for payroll packaging") if lines.empty?
      packet = packet_payload(lines:, holdbacks:, requested_by:)

      @employer.update!(settings: @employer.settings.to_h.merge(PACKET_KEY => packet))
      packet
    end

    private

    def apply_pay_change(change, run:)
      if change.base_pay_change?
        apply_base_pay_change(change)
      elsif change.one_time_change?
        apply_one_time_change(change, run:)
      end
    end

    def apply_base_pay_change(change)
      change.employee.update!(
        compensation_cents: change.proposed_compensation_cents,
        metadata: change.employee.metadata.to_h.merge(
          "last_compensation_change_id" => change.id,
          "last_compensation_change_at" => Time.current.iso8601
        )
      )
    end

    def apply_one_time_change(change, run:)
      unless run
        change.errors.add(:base, "A payroll run is required before one-time compensation can be applied")
        raise ActiveRecord::RecordInvalid, change
      end

      run.payroll_adjustments.create!(
        employee: change.employee,
        adjustment_type: change.change_type,
        description: "#{change.reason} (change ##{change.id})",
        amount_cents: change.delta_cents,
        taxable: true
      )
    end

    def change_holdbacks
      changes.not_applied.reject(&:approved?).map do |change|
        if change.rejected?
          holdback_line(change, reason: change.rejection_reason.presence || "Rejected compensation change is excluded from payroll packaging")
        else
          holdback_line(change, reason: "Approval is required before this compensation change can be packaged")
        end
      end
    end

    def packet_payload(lines:, holdbacks:, requested_by:)
      {
        "packet_id" => "comp_changes_#{@employer.id}_#{Time.current.to_i}",
        "generated_at" => Time.current.iso8601,
        "requested_by" => requested_by,
        "employer_id" => @employer.id,
        "payroll_run_id" => payroll_run&.id,
        "status" => lines.any? && holdbacks.empty? ? "ready" : "needs_review",
        "totals" => {
          "change_count" => lines.count,
          "employee_count" => lines.map { |line| line.fetch("employee_id") }.uniq.count,
          "recurring_delta_cents" => lines.select { |line| line.fetch("base_pay_change") }.sum { |line| line.fetch("delta_cents") },
          "one_time_cents" => lines.reject { |line| line.fetch("base_pay_change") }.sum { |line| line.fetch("delta_cents") },
          "holdback_count" => holdbacks.count
        },
        "changes" => lines,
        "holdbacks" => holdbacks
      }
    end

    def packet_line(change)
      {
        "change_id" => change.id,
        "employee_id" => change.employee_id,
        "employee_name" => change.employee.full_name,
        "department_name" => change.employee.department&.name || "Unassigned",
        "change_type" => change.change_type,
        "reason" => change.reason,
        "effective_on" => change.effective_on.iso8601,
        "current_compensation_cents" => change.current_compensation_cents,
        "proposed_compensation_cents" => change.proposed_compensation_cents,
        "delta_cents" => change.delta_cents,
        "base_pay_change" => change.base_pay_change?,
        "payroll_run_id" => change.payroll_run_id || payroll_run&.id,
        "status" => "ready"
      }
    end

    def holdback_line(change, reason:)
      {
        "change_id" => change.id,
        "employee_id" => change.employee_id,
        "employee_name" => change.employee.full_name,
        "change_type" => change.change_type,
        "status" => change.status,
        "reason" => reason
      }
    end

    def empty_holdback(reason)
      {
        "change_id" => nil,
        "employee_id" => nil,
        "employee_name" => "Compensation review",
        "change_type" => "approval_queue",
        "status" => "needs_review",
        "reason" => reason
      }
    end
  end
end
