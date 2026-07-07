module Vitable
  ApiSnapshotDto = Data.define(
    :refreshed_at,
    :remote_employer_count,
    :remote_group_count,
    :remote_plan_count,
    :remote_webhook_event_count,
    :remote_employee_enrollment_count,
    :mapped_employee_count
  ) do
    def self.from_metadata(metadata)
      payload = metadata.to_h.fetch("api_snapshot", {}).to_h
      counts = payload.fetch("counts", {}).to_h
      employee_enrollments = payload.fetch("employee_enrollments", [])

      new(
        refreshed_at: payload["refreshed_at"].present? ? Time.iso8601(payload.fetch("refreshed_at")) : nil,
        remote_employer_count: counts.fetch("remote_employer_count", 0),
        remote_group_count: counts.fetch("remote_group_count", 0),
        remote_plan_count: counts.fetch("remote_plan_count", 0),
        remote_webhook_event_count: counts.fetch("remote_webhook_event_count", 0),
        remote_employee_enrollment_count: counts.fetch("remote_employee_enrollment_count", 0),
        mapped_employee_count: employee_enrollments.count
      )
    end

    def present?
      refreshed_at.present?
    end
  end
end
