module Garnishments
  AgencySummaryDto = Data.define(:agency_name, :service_state, :remittance_method, :line_count, :employee_count, :amount_cents) do
    def self.from_hash(payload)
      attributes = payload.to_h.stringify_keys

      new(
        agency_name: attributes.fetch("agency_name"),
        service_state: attributes.fetch("service_state", "Federal"),
        remittance_method: attributes.fetch("remittance_method", "agency_ach"),
        line_count: attributes.fetch("line_count", 0),
        employee_count: attributes.fetch("employee_count", 0),
        amount_cents: attributes.fetch("amount_cents", 0)
      )
    end
  end
end
