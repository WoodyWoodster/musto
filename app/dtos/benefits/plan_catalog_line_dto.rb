module Benefits
  PlanCatalogLineDto = Data.define(:plan_id, :plan_name, :category, :carrier, :plan_year, :monthly_premium_cents, :employee_contribution_cents, :employer_contribution_cents, :eligibility_rule, :remote_action, :status) do
    def self.from_hash(payload)
      attributes = payload.to_h.stringify_keys

      new(
        plan_id: attributes.fetch("plan_id"),
        plan_name: attributes.fetch("plan_name"),
        category: attributes.fetch("category"),
        carrier: attributes.fetch("carrier", nil),
        plan_year: attributes.fetch("plan_year", nil),
        monthly_premium_cents: attributes.fetch("monthly_premium_cents", 0),
        employee_contribution_cents: attributes.fetch("employee_contribution_cents", 0),
        employer_contribution_cents: attributes.fetch("employer_contribution_cents", 0),
        eligibility_rule: attributes.fetch("eligibility_rule", "active_full_time"),
        remote_action: attributes.fetch("remote_action"),
        status: attributes.fetch("status")
      )
    end
  end
end
