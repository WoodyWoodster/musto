module Benefits
  DependentVerificationIssueDto = Data.define(:dependent_id, :dependent_name, :employee_name, :status, :reason_code, :reason) do
    def self.from_hash(payload)
      attributes = payload.to_h.stringify_keys

      new(
        dependent_id: attributes.fetch("dependent_id", nil),
        dependent_name: attributes.fetch("dependent_name"),
        employee_name: attributes.fetch("employee_name"),
        status: attributes.fetch("status", "needs_review"),
        reason_code: attributes.fetch("reason_code"),
        reason: attributes.fetch("reason")
      )
    end
  end
end
