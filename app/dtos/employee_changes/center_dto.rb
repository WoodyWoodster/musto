module EmployeeChanges
  CenterDto = Data.define(:employer, :metrics, :requests, :type_summaries, :impact_items, :sync_batches, :sync_lines, :sync_holdbacks, :sync_payload) do
    def latest_batch
      sync_batches.first
    end

    def reviewable_requests
      requests.select(&:reviewable?)
    end

    def applied_requests
      requests.select(&:applied?)
    end
  end
end
