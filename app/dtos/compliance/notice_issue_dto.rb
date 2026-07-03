module Compliance
  NoticeIssueDto = Data.define(
    :notice_id,
    :title,
    :agency_name,
    :jurisdiction,
    :notice_type,
    :severity,
    :status,
    :reason_code,
    :reason,
    :response_owner,
    :due_on
  ) do
    def self.from_hash(payload)
      attributes = payload.to_h.stringify_keys

      new(
        notice_id: attributes.fetch("notice_id"),
        title: attributes.fetch("title"),
        agency_name: attributes.fetch("agency_name"),
        jurisdiction: attributes.fetch("jurisdiction"),
        notice_type: attributes.fetch("notice_type"),
        severity: attributes.fetch("severity"),
        status: attributes.fetch("status"),
        reason_code: attributes.fetch("reason_code"),
        reason: attributes.fetch("reason"),
        response_owner: attributes.fetch("response_owner"),
        due_on: Date.iso8601(attributes.fetch("due_on"))
      )
    end
  end
end
