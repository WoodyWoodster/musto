module Hiring
  HandoffHoldbackDto = Data.define(:candidate_id, :candidate_name, :job_title, :reason, :status) do
    def self.from_hash(payload)
      attributes = payload.to_h.stringify_keys

      new(
        candidate_id: attributes.fetch("candidate_id"),
        candidate_name: attributes.fetch("candidate_name"),
        job_title: attributes.fetch("job_title"),
        reason: attributes.fetch("reason"),
        status: attributes.fetch("status")
      )
    end
  end
end
