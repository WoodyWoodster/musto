module Vitable
  EmployerProvisioningPayloadDto = Data.define(
    :mode,
    :endpoint,
    :name,
    :legal_name,
    :ein,
    :email,
    :phone_number,
    :reference_id,
    :address_line_1,
    :city,
    :state,
    :zipcode,
    :pay_frequency,
    :eligibility_classification,
    :eligibility_waiting_period,
    :create_payload,
    :settings_payload,
    :eligibility_policy_payload
  ) do
    def self.from_hash(payload)
      attributes = payload.to_h.stringify_keys
      create_payload = attributes.fetch("create_payload", {}).to_h.stringify_keys
      address = create_payload.fetch("address", {}).to_h.stringify_keys
      settings_payload = attributes.fetch("settings_payload", {}).to_h.stringify_keys
      eligibility_policy_payload = attributes.fetch("eligibility_policy_payload", {}).to_h.stringify_keys

      new(
        mode: attributes.fetch("mode"),
        endpoint: attributes.fetch("endpoint"),
        name: create_payload.fetch("name", nil),
        legal_name: create_payload.fetch("legal_name", nil),
        ein: create_payload.fetch("ein", nil),
        email: create_payload.fetch("email", nil),
        phone_number: create_payload.fetch("phone_number", nil),
        reference_id: create_payload.fetch("reference_id", nil),
        address_line_1: address.fetch("address_line_1", nil),
        city: address.fetch("city", nil),
        state: address.fetch("state", nil),
        zipcode: address.fetch("zipcode", nil),
        pay_frequency: settings_payload.fetch("pay_frequency", nil),
        eligibility_classification: eligibility_policy_payload.fetch("classification", nil),
        eligibility_waiting_period: eligibility_policy_payload.fetch("waiting_period", nil),
        create_payload:,
        settings_payload:,
        eligibility_policy_payload:
      )
    end
  end
end
