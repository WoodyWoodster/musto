module Benefits
  VitablePlanMappingIssueDto = Data.define(:issue_type, :remote_plan_id, :remote_plan_name, :local_plan_id, :local_plan_name, :candidate_plan_names, :category) do
    def self.unmatched_remote(payload)
      attributes = payload.to_h.stringify_keys

      new(
        issue_type: "unmatched_remote",
        remote_plan_id: attributes.fetch("id", nil),
        remote_plan_name: attributes.fetch("name", nil),
        local_plan_id: nil,
        local_plan_name: nil,
        candidate_plan_names: [],
        category: nil
      )
    end

    def self.unmatched_local(payload)
      attributes = payload.to_h.stringify_keys

      new(
        issue_type: "unmatched_local",
        remote_plan_id: nil,
        remote_plan_name: nil,
        local_plan_id: attributes.fetch("local_plan_id", nil),
        local_plan_name: attributes.fetch("local_plan_name", nil),
        candidate_plan_names: [],
        category: attributes.fetch("category", nil)
      )
    end

    def self.ambiguous_remote(payload)
      attributes = payload.to_h.stringify_keys

      new(
        issue_type: "ambiguous_remote",
        remote_plan_id: attributes.fetch("remote_plan_id", nil),
        remote_plan_name: attributes.fetch("remote_plan_name", nil),
        local_plan_id: nil,
        local_plan_name: nil,
        candidate_plan_names: attributes.fetch("candidate_plan_names", []),
        category: nil
      )
    end

    def title
      remote_plan_name.presence || local_plan_name
    end
  end
end
