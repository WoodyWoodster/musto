module WorkersComp
  IssueDto = Data.define(:reason_code, :severity, :status, :reason, :policy_id) do
    def self.from_hash(payload)
      attributes = payload.to_h.stringify_keys

      new(
        reason_code: attributes.fetch("reason_code"),
        severity: attributes.fetch("severity"),
        status: attributes.fetch("status"),
        reason: attributes.fetch("reason"),
        policy_id: attributes.fetch("policy_id", nil)
      )
    end
  end
end
