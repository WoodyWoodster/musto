module Vitable
  ApiSnapshotDto = Data.define(
    :refreshed_at,
    :remote_employer_count,
    :mapped_employer_count,
    :unmatched_remote_employer_count,
    :conflicting_remote_employer_count,
    :remote_group_count,
    :mapped_group_count,
    :unmatched_remote_group_count,
    :conflicting_remote_group_count,
    :remote_plan_count,
    :mapped_plan_count,
    :unmatched_remote_plan_count,
    :unmatched_local_plan_count,
    :ambiguous_remote_plan_count,
    :remote_webhook_event_count,
    :imported_webhook_event_count,
    :existing_webhook_event_count,
    :webhook_recovery_candidate_count,
    :recovered_webhook_event_count,
    :failed_webhook_recovery_count,
    :skipped_webhook_recovery_count,
    :remote_employee_count,
    :remote_employee_enrollment_count,
    :reconciled_enrollment_count,
    :created_enrollment_count,
    :updated_enrollment_count,
    :enrollment_missing_plan_count,
    :enrollment_deduction_changed_count,
    :mapped_employee_count,
    :unmatched_remote_employee_count,
    :remote_employee_deduction_changed_count,
    :inactive_employee_enrollment_count,
    :inactive_employee_payroll_deduction_count
  ) do
    def self.from_metadata(metadata)
      payload = metadata.to_h.fetch("api_snapshot", {}).to_h
      counts = payload.fetch("counts", {}).to_h
      employee_enrollments = payload.fetch("employee_enrollments", [])
      remote_employee_rosters = payload.fetch("remote_employee_rosters", [])

      new(
        refreshed_at: payload["refreshed_at"].present? ? Time.iso8601(payload.fetch("refreshed_at")) : nil,
        remote_employer_count: counts.fetch("remote_employer_count", 0),
        mapped_employer_count: counts.fetch("mapped_employer_count", 0),
        unmatched_remote_employer_count: counts.fetch("unmatched_remote_employer_count", 0),
        conflicting_remote_employer_count: counts.fetch("conflicting_remote_employer_count", 0),
        remote_group_count: counts.fetch("remote_group_count", 0),
        mapped_group_count: counts.fetch("mapped_group_count", 0),
        unmatched_remote_group_count: counts.fetch("unmatched_remote_group_count", 0),
        conflicting_remote_group_count: counts.fetch("conflicting_remote_group_count", 0),
        remote_plan_count: counts.fetch("remote_plan_count", 0),
        mapped_plan_count: counts.fetch("mapped_plan_count", 0),
        unmatched_remote_plan_count: counts.fetch("unmatched_remote_plan_count", 0),
        unmatched_local_plan_count: counts.fetch("unmatched_local_plan_count", 0),
        ambiguous_remote_plan_count: counts.fetch("ambiguous_remote_plan_count", 0),
        remote_webhook_event_count: counts.fetch("remote_webhook_event_count", 0),
        imported_webhook_event_count: counts.fetch("imported_webhook_event_count", 0),
        existing_webhook_event_count: counts.fetch("existing_webhook_event_count", 0),
        webhook_recovery_candidate_count: counts.fetch("webhook_recovery_candidate_count", 0),
        recovered_webhook_event_count: counts.fetch("recovered_webhook_event_count", 0),
        failed_webhook_recovery_count: counts.fetch("failed_webhook_recovery_count", 0),
        skipped_webhook_recovery_count: counts.fetch("skipped_webhook_recovery_count", 0),
        remote_employee_count: counts.fetch("remote_employee_count", remote_employee_rosters.sum { |entry| entry.to_h.fetch("employees", []).count }),
        remote_employee_enrollment_count: counts.fetch("remote_employee_enrollment_count", 0),
        reconciled_enrollment_count: counts.fetch("reconciled_enrollment_count", 0),
        created_enrollment_count: counts.fetch("created_enrollment_count", 0),
        updated_enrollment_count: counts.fetch("updated_enrollment_count", 0),
        enrollment_missing_plan_count: counts.fetch("enrollment_missing_plan_count", 0),
        enrollment_deduction_changed_count: counts.fetch("enrollment_deduction_changed_count", 0),
        mapped_employee_count: counts.fetch("mapped_employee_count", employee_enrollments.count),
        unmatched_remote_employee_count: counts.fetch("unmatched_remote_employee_count", 0),
        remote_employee_deduction_changed_count: counts.fetch("remote_employee_deduction_changed_count", 0),
        inactive_employee_enrollment_count: counts.fetch("inactive_employee_enrollment_count", 0),
        inactive_employee_payroll_deduction_count: counts.fetch("inactive_employee_payroll_deduction_count", 0)
      )
    end

    def present?
      refreshed_at.present?
    end
  end
end
