module Vitable
  CareMemberSyncManifestDto = Data.define(
    :manifest_id,
    :generated_at,
    :requested_by,
    :employer_id,
    :remote_group_id,
    :endpoint,
    :status,
    :employee_count,
    :ready_count,
    :holdback_count,
    :remote_plan_missing_count,
    :max_members
  ) do
    def self.from_hash(payload)
      attributes = payload.to_h.stringify_keys
      totals = attributes.fetch("totals", {}).to_h.stringify_keys
      limits = attributes.fetch("limits", {}).to_h.stringify_keys

      new(
        manifest_id: attributes.fetch("manifest_id"),
        generated_at: Time.iso8601(attributes.fetch("generated_at")),
        requested_by: attributes.fetch("requested_by", "ops_console"),
        employer_id: attributes.fetch("employer_id"),
        remote_group_id: attributes.fetch("remote_group_id", nil),
        endpoint: attributes.fetch("endpoint"),
        status: attributes.fetch("status"),
        employee_count: totals.fetch("employee_count", 0),
        ready_count: totals.fetch("ready_count", 0),
        holdback_count: totals.fetch("holdback_count", 0),
        remote_plan_missing_count: totals.fetch("remote_plan_missing_count", 0),
        max_members: limits.fetch("max_members", CareGroupRepository::MAX_MEMBERS)
      )
    end
  end
end
