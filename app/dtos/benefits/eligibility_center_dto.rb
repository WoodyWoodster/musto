module Benefits
  EligibilityCenterDto = Data.define(
    :employer,
    :metrics,
    :members,
    :dependents,
    :issues,
    :batches,
    :batch_members,
    :batch_holdbacks,
    :batch_payload
  ) do
    def generated?
      batch_payload.present?
    end

    def latest_batch
      batches.first
    end

    def ready_members
      members.select(&:ready?)
    end

    def review_dependents
      dependents.reject(&:eligible?)
    end
  end
end
