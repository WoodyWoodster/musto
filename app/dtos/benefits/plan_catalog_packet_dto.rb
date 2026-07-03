module Benefits
  PlanCatalogPacketDto = Data.define(:packet_id, :generated_at, :requested_by, :status, :plan_count, :ready_count, :holdback_count, :monthly_premium_cents, :employee_contribution_cents, :employer_contribution_cents) do
    def self.from_hash(payload)
      attributes = payload.to_h.stringify_keys
      totals = attributes.fetch("totals", {}).to_h.stringify_keys

      new(
        packet_id: attributes.fetch("packet_id"),
        generated_at: Time.iso8601(attributes.fetch("generated_at")),
        requested_by: attributes.fetch("requested_by", "ops_console"),
        status: attributes.fetch("status"),
        plan_count: totals.fetch("plan_count", 0),
        ready_count: totals.fetch("ready_count", 0),
        holdback_count: totals.fetch("holdback_count", 0),
        monthly_premium_cents: totals.fetch("monthly_premium_cents", 0),
        employee_contribution_cents: totals.fetch("employee_contribution_cents", 0),
        employer_contribution_cents: totals.fetch("employer_contribution_cents", 0)
      )
    end
  end
end
