module WorkersComp
  AuditClaimDto = Data.define(:claim_id, :employee_id, :employee_name, :claim_number, :incident_on, :reported_on, :status, :severity, :injury_type, :body_part, :lost_time_days, :reserve_cents, :paid_cents, :return_to_work_on) do
    def self.from_hash(payload)
      attributes = payload.to_h.stringify_keys

      new(
        claim_id: attributes.fetch("claim_id"),
        employee_id: attributes.fetch("employee_id"),
        employee_name: attributes.fetch("employee_name"),
        claim_number: attributes.fetch("claim_number", nil),
        incident_on: Date.iso8601(attributes.fetch("incident_on")),
        reported_on: Date.iso8601(attributes.fetch("reported_on")),
        status: attributes.fetch("status"),
        severity: attributes.fetch("severity"),
        injury_type: attributes.fetch("injury_type", nil),
        body_part: attributes.fetch("body_part", nil),
        lost_time_days: attributes.fetch("lost_time_days", 0),
        reserve_cents: attributes.fetch("reserve_cents", 0),
        paid_cents: attributes.fetch("paid_cents", 0),
        return_to_work_on: attributes.fetch("return_to_work_on", nil).present? ? Date.iso8601(attributes.fetch("return_to_work_on")) : nil
      )
    end
  end
end
