module Lifecycle
  CenterDto = Data.define(
    :employer,
    :metrics,
    :events,
    :impact_items,
    :batches,
    :batch_lines,
    :batch_holdbacks,
    :batch_payload
  ) do
    def generated?
      batch_payload.present?
    end

    def latest_batch
      batches.first
    end

    def pending_events
      events.select(&:draft?)
    end

    def approved_events
      events.select(&:approved?)
    end
  end
end
