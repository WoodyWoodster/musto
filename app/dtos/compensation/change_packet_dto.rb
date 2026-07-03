module Compensation
  ChangePacketDto = Data.define(
    :packet_id,
    :generated_at,
    :requested_by,
    :employer_id,
    :payroll_run_id,
    :status,
    :change_count,
    :employee_count,
    :recurring_delta_cents,
    :one_time_cents,
    :holdback_count
  ) do
    def self.from_hash(payload)
      attributes = payload.to_h.stringify_keys
      totals = attributes.fetch("totals", {}).to_h.stringify_keys

      new(
        packet_id: attributes.fetch("packet_id"),
        generated_at: Time.iso8601(attributes.fetch("generated_at")),
        requested_by: attributes.fetch("requested_by", "ops_console"),
        employer_id: attributes.fetch("employer_id"),
        payroll_run_id: attributes.fetch("payroll_run_id", nil),
        status: attributes.fetch("status"),
        change_count: totals.fetch("change_count", 0),
        employee_count: totals.fetch("employee_count", 0),
        recurring_delta_cents: totals.fetch("recurring_delta_cents", 0),
        one_time_cents: totals.fetch("one_time_cents", 0),
        holdback_count: totals.fetch("holdback_count", 0)
      )
    end
  end
end
