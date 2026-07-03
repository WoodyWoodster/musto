module Reports
  CenterDto = Data.define(
    :employer,
    :metrics,
    :report_cards,
    :department_costs,
    :benefit_spend,
    :risk_items,
    :snapshots,
    :snapshot_payload
  ) do
    def generated?
      snapshot_payload.present?
    end

    def latest_snapshot
      snapshots.first
    end
  end
end
