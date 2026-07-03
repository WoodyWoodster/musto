module Compensation
  PacketDto = Data.define(
    :packet_id,
    :generated_at,
    :status,
    :requested_by,
    :employee_count,
    :annual_compensation_cents,
    :adjustment_cents,
    :department_budget_cents,
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
        employee_count: totals.fetch("employee_count", 0),
        annual_compensation_cents: totals.fetch("annual_compensation_cents", 0),
        adjustment_cents: totals.fetch("adjustment_cents", 0),
        department_budget_cents: totals.fetch("department_budget_cents", 0),
        recommendation_count: attributes.fetch("recommendations", []).count
      )
    end
  end
end
