module Taxes
  AgencyRegistrationPacketLineDto = Data.define(
    :registration_id,
    :agency_name,
    :jurisdiction,
    :registration_type,
    :account_number,
    :deposit_schedule,
    :status,
    :risk_level,
    :due_on,
    :submitted_at,
    :confirmed_at,
    :confirmation_number,
    :next_deposit_due_on,
    :owner,
    :location_name,
    :notes
  ) do
    def self.from_hash(payload)
      attributes = payload.to_h.stringify_keys

      new(
        registration_id: attributes.fetch("registration_id"),
        agency_name: attributes.fetch("agency_name"),
        jurisdiction: attributes.fetch("jurisdiction"),
        registration_type: attributes.fetch("registration_type"),
        account_number: attributes.fetch("account_number", nil),
        deposit_schedule: attributes.fetch("deposit_schedule"),
        status: attributes.fetch("status"),
        risk_level: attributes.fetch("risk_level"),
        due_on: Date.iso8601(attributes.fetch("due_on")),
        submitted_at: parse_time(attributes.fetch("submitted_at", nil)),
        confirmed_at: parse_time(attributes.fetch("confirmed_at", nil)),
        confirmation_number: attributes.fetch("confirmation_number", nil),
        next_deposit_due_on: parse_date(attributes.fetch("next_deposit_due_on", nil)),
        owner: attributes.fetch("owner"),
        location_name: attributes.fetch("location_name", nil),
        notes: attributes.fetch("notes", nil)
      )
    end

    def self.parse_time(value)
      value.present? ? Time.iso8601(value) : nil
    end

    def self.parse_date(value)
      value.present? ? Date.iso8601(value) : nil
    end
  end
end
