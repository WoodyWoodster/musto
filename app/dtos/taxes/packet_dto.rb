module Taxes
  PacketDto = Data.define(
    :packet_id,
    :generated_at,
    :status,
    :requested_by,
    :payroll_run_count,
    :gross_pay_cents,
    :employee_tax_cents,
    :employer_tax_cents,
    :total_liability_cents,
    :agency_account_count,
    :recommendation_count
  ) do
    def self.from_hash(payload)
      attributes = payload.to_h.stringify_keys
      totals = attributes.fetch("totals", {}).to_h.stringify_keys

      new(
        packet_id: attributes.fetch("packet_id"),
        generated_at: Time.iso8601(attributes.fetch("generated_at")),
        status: attributes.fetch("status"),
        requested_by: attributes.fetch("requested_by", "ops_console"),
        payroll_run_count: totals.fetch("payroll_run_count", 0),
        gross_pay_cents: totals.fetch("gross_pay_cents", 0),
        employee_tax_cents: totals.fetch("employee_tax_cents", 0),
        employer_tax_cents: totals.fetch("employer_tax_cents", 0),
        total_liability_cents: totals.fetch("total_liability_cents", 0),
        agency_account_count: totals.fetch("agency_account_count", 0),
        recommendation_count: attributes.fetch("recommendations", []).count
      )
    end
  end
end
