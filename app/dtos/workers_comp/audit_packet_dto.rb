module WorkersComp
  AuditPacketDto = Data.define(:packet_id, :generated_at, :requested_by, :policy_id, :policy_number, :status, :coverage_start_on, :coverage_end_on, :exposure_count, :employee_count, :payroll_basis_cents, :estimated_premium_cents, :claim_count, :open_claim_count, :reserve_cents, :holdback_count) do
    def self.from_hash(payload)
      attributes = payload.to_h.stringify_keys
      totals = attributes.fetch("totals", {}).to_h.stringify_keys

      new(
        packet_id: attributes.fetch("packet_id"),
        generated_at: Time.iso8601(attributes.fetch("generated_at")),
        requested_by: attributes.fetch("requested_by", "compliance_ops"),
        policy_id: attributes.fetch("policy_id", nil),
        policy_number: attributes.fetch("policy_number", nil),
        status: attributes.fetch("status", "needs_review"),
        coverage_start_on: parse_date(attributes.fetch("coverage_start_on", nil)),
        coverage_end_on: parse_date(attributes.fetch("coverage_end_on", nil)),
        exposure_count: totals.fetch("exposure_count", 0),
        employee_count: totals.fetch("employee_count", 0),
        payroll_basis_cents: totals.fetch("payroll_basis_cents", 0),
        estimated_premium_cents: totals.fetch("estimated_premium_cents", 0),
        claim_count: totals.fetch("claim_count", 0),
        open_claim_count: totals.fetch("open_claim_count", 0),
        reserve_cents: totals.fetch("reserve_cents", 0),
        holdback_count: totals.fetch("holdback_count", 0)
      )
    end

    def self.parse_date(value)
      value.present? ? Date.iso8601(value) : nil
    end
  end
end
