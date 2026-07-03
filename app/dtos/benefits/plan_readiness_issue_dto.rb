module Benefits
  PlanReadinessIssueDto = Data.define(:plan_id, :plan_name, :severity, :status, :reason_code, :reason) do
    def self.from_hash(payload)
      attributes = payload.to_h.stringify_keys

      new(
        plan_id: attributes.fetch("plan_id", nil),
        plan_name: attributes.fetch("plan_name"),
        severity: attributes.fetch("severity", "medium"),
        status: attributes.fetch("status", "needs_review"),
        reason_code: attributes.fetch("reason_code"),
        reason: attributes.fetch("reason")
      )
    end
  end
end
