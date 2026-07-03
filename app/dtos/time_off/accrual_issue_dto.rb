module TimeOff
  AccrualIssueDto = Data.define(:employee_id, :employee_name, :policy_name, :status, :reason_code, :reason) do
    def self.from_hash(payload)
      attributes = payload.to_h.stringify_keys

      new(
        employee_id: attributes.fetch("employee_id", nil),
        employee_name: attributes.fetch("employee_name"),
        policy_name: attributes.fetch("policy_name", nil),
        status: attributes.fetch("status", "needs_review"),
        reason_code: attributes.fetch("reason_code"),
        reason: attributes.fetch("reason")
      )
    end
  end
end
