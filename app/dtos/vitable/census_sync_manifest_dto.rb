module Vitable
  CensusSyncManifestDto = Data.define(
    :batch_id,
    :generated_at,
    :requested_by,
    :employer_id,
    :remote_employer_id,
    :endpoint,
    :status,
    :employee_count,
    :ready_count,
    :holdback_count,
    :remote_pending_count,
    :offboarding_omission_count,
    :max_employees
  ) do
    def self.from_hash(payload)
      attributes = payload.to_h.stringify_keys
      totals = attributes.fetch("totals", {}).to_h.stringify_keys
      limits = attributes.fetch("limits", {}).to_h.stringify_keys

      new(
        batch_id: attributes.fetch("batch_id"),
        generated_at: Time.iso8601(attributes.fetch("generated_at")),
        requested_by: attributes.fetch("requested_by", "ops_console"),
        employer_id: attributes.fetch("employer_id"),
        remote_employer_id: attributes.fetch("remote_employer_id", nil),
        endpoint: attributes.fetch("endpoint"),
        status: attributes.fetch("status"),
        employee_count: totals.fetch("employee_count", 0),
        ready_count: totals.fetch("ready_count", 0),
        holdback_count: totals.fetch("holdback_count", 0),
        remote_pending_count: totals.fetch("remote_pending_count", 0),
        offboarding_omission_count: totals.fetch("offboarding_omission_count", 0),
        max_employees: limits.fetch("max_employees", CensusSyncRepository::MAX_EMPLOYEES)
      )
    end
  end
end
