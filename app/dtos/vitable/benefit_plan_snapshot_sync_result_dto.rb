module Vitable
  BenefitPlanSnapshotSyncResultDto = Data.define(:updated_ids, :unchanged_ids, :conflicts) do
    def self.empty
      new(updated_ids: [], unchanged_ids: [], conflicts: [])
    end

    def merge(other)
      self.class.new(
        updated_ids: updated_ids + other.updated_ids,
        unchanged_ids: unchanged_ids + other.unchanged_ids,
        conflicts: conflicts + other.conflicts
      )
    end

    def record_updated(id)
      self.class.new(updated_ids: updated_ids + [ id ], unchanged_ids:, conflicts:)
    end

    def record_unchanged(id)
      self.class.new(updated_ids:, unchanged_ids: unchanged_ids + [ id ], conflicts:)
    end

    def record_conflict(plan:, remote_plan_id:, conflicting_plan:)
      self.class.new(
        updated_ids:,
        unchanged_ids:,
        conflicts: conflicts + [
          {
            "local_plan_id" => plan.id,
            "local_plan_name" => plan.name,
            "remote_plan_id" => remote_plan_id,
            "conflicting_local_plan_id" => conflicting_plan.id,
            "conflicting_local_plan_name" => conflicting_plan.name
          }
        ]
      )
    end

    def applied_changes
      updated_ids.map { |id| "benefit_plans.#{id}" }
    end

    def to_metadata
      {
        "updated_count" => updated_ids.count,
        "unchanged_count" => unchanged_ids.count,
        "conflict_count" => conflicts.count,
        "updated_ids" => updated_ids,
        "unchanged_ids" => unchanged_ids,
        "conflicts" => conflicts
      }
    end
  end
end
