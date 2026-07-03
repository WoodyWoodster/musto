module Compliance
  NoticePacketLineDto = Data.define(
    :notice_id,
    :employee_id,
    :employee_name,
    :source,
    :notice_type,
    :title,
    :agency_name,
    :jurisdiction,
    :reference_number,
    :severity,
    :status,
    :received_on,
    :due_on,
    :amount_cents,
    :response_owner,
    :response_channel,
    :summary,
    :resolution_summary,
    :acknowledged_at,
    :responded_at,
    :resolved_at
  ) do
    def self.from_hash(payload)
      attributes = payload.to_h.stringify_keys

      new(
        notice_id: attributes.fetch("notice_id"),
        employee_id: attributes.fetch("employee_id", nil),
        employee_name: attributes.fetch("employee_name", nil),
        source: attributes.fetch("source"),
        notice_type: attributes.fetch("notice_type"),
        title: attributes.fetch("title"),
        agency_name: attributes.fetch("agency_name"),
        jurisdiction: attributes.fetch("jurisdiction"),
        reference_number: attributes.fetch("reference_number", nil),
        severity: attributes.fetch("severity"),
        status: attributes.fetch("status"),
        received_on: Date.iso8601(attributes.fetch("received_on")),
        due_on: Date.iso8601(attributes.fetch("due_on")),
        amount_cents: attributes.fetch("amount_cents", 0),
        response_owner: attributes.fetch("response_owner"),
        response_channel: attributes.fetch("response_channel"),
        summary: attributes.fetch("summary", nil),
        resolution_summary: attributes.fetch("resolution_summary", nil),
        acknowledged_at: parse_time(attributes.fetch("acknowledged_at", nil)),
        responded_at: parse_time(attributes.fetch("responded_at", nil)),
        resolved_at: parse_time(attributes.fetch("resolved_at", nil))
      )
    end

    def self.parse_time(value)
      value.present? ? Time.iso8601(value) : nil
    end
  end
end
