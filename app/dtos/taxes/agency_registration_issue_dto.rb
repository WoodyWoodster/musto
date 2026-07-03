module Taxes
  AgencyRegistrationIssueDto = Data.define(
    :registration_id,
    :agency_name,
    :jurisdiction,
    :registration_type,
    :severity,
    :status,
    :reason_code,
    :reason,
    :owner,
    :due_on
  ) do
    def self.from_hash(payload)
      attributes = payload.to_h.stringify_keys

      new(
        registration_id: attributes.fetch("registration_id"),
        agency_name: attributes.fetch("agency_name"),
        jurisdiction: attributes.fetch("jurisdiction"),
        registration_type: attributes.fetch("registration_type"),
        severity: attributes.fetch("severity"),
        status: attributes.fetch("status"),
        reason_code: attributes.fetch("reason_code"),
        reason: attributes.fetch("reason"),
        owner: attributes.fetch("owner"),
        due_on: Date.iso8601(attributes.fetch("due_on"))
      )
    end
  end
end
