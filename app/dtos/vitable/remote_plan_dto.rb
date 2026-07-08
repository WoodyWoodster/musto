module Vitable
  RemotePlanDto = Data.define(
    :remote_plan_id,
    :name,
    :raw_payload
  ) do
    def self.from_hash(payload)
      attributes = payload.respond_to?(:to_h) ? payload.to_h.stringify_keys : {}
      data = attributes.fetch("data", attributes)
      data = data.fetch("plan", data) if data.respond_to?(:fetch)
      data = data.respond_to?(:to_h) ? data.to_h.stringify_keys : {}

      new(
        remote_plan_id: data.fetch("id", nil),
        name: data.fetch("name", nil),
        raw_payload: data
      )
    end

    def validate!(response_label: "Vitable plan catalog item")
      reference = name.presence || remote_plan_id.presence || "unknown plan"
      raise ArgumentError, "#{response_label} #{reference} did not include a remote plan ID" if remote_plan_id.blank?
      raise ArgumentError, "#{response_label} #{remote_plan_id} did not include a remote plan name" if name.blank?

      self
    end

    def to_snapshot_hash
      raw_payload.merge(
        "id" => remote_plan_id,
        "name" => name
      )
    end
  end
end
