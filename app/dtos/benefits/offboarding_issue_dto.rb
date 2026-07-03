module Benefits
  OffboardingIssueDto = Data.define(:event_id, :employee_id, :employee_name, :severity, :status, :reason_code, :reason) do
    def self.from_hash(payload)
      attributes = payload.to_h.stringify_keys

      new(
        event_id: attributes.fetch("event_id", nil),
        employee_id: attributes.fetch("employee_id", nil),
        employee_name: attributes.fetch("employee_name"),
        severity: attributes.fetch("severity", "medium"),
        status: attributes.fetch("status", "needs_review"),
        reason_code: attributes.fetch("reason_code"),
        reason: attributes.fetch("reason")
      )
    end
  end
end
