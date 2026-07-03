module Lifecycle
  SyncHoldbackDto = Data.define(:event_id, :employee_id, :employee_name, :event_type, :effective_on, :status, :reason) do
    def self.from_hash(payload)
      attributes = payload.to_h.stringify_keys

      new(
        event_id: attributes.fetch("event_id"),
        employee_id: attributes.fetch("employee_id"),
        employee_name: attributes.fetch("employee_name"),
        event_type: attributes.fetch("event_type"),
        effective_on: Date.iso8601(attributes.fetch("effective_on")),
        status: attributes.fetch("status"),
        reason: attributes.fetch("reason")
      )
    end
  end
end
