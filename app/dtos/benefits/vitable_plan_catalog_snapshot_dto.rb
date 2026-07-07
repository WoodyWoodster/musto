module Benefits
  VitablePlanCatalogSnapshotDto = Data.define(
    :refreshed_at,
    :remote_plan_count,
    :mapped_plan_count,
    :unmatched_remote_count,
    :unmatched_local_count,
    :ambiguous_remote_count
  ) do
    def self.from_hash(payload)
      attributes = payload.to_h.stringify_keys

      new(
        refreshed_at: attributes["refreshed_at"].present? ? Time.iso8601(attributes.fetch("refreshed_at")) : nil,
        remote_plan_count: attributes.fetch("remote_plans", []).count,
        mapped_plan_count: attributes.fetch("mapped_plan_count", 0),
        unmatched_remote_count: attributes.fetch("unmatched_remote_plans", []).count,
        unmatched_local_count: attributes.fetch("unmatched_local_plans", []).count,
        ambiguous_remote_count: attributes.fetch("ambiguous_remote_plans", []).count
      )
    end

    def present?
      refreshed_at.present?
    end
  end
end
