module Benefits
  VitablePlanMappingDto = Data.define(
    :local_plan_id,
    :local_plan_name,
    :remote_plan_id,
    :remote_plan_name,
    :category
  ) do
    def self.from_hash(payload)
      attributes = payload.to_h.stringify_keys

      new(
        local_plan_id: attributes.fetch("local_plan_id"),
        local_plan_name: attributes.fetch("local_plan_name"),
        remote_plan_id: attributes.fetch("remote_plan_id"),
        remote_plan_name: attributes.fetch("remote_plan_name"),
        category: attributes.fetch("category", nil)
      )
    end
  end
end
