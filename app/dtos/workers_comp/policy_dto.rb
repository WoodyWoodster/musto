module WorkersComp
  PolicyDto = Data.define(:id, :carrier, :policy_number, :status, :coverage_start_on, :coverage_end_on, :renewal_due_on, :payroll_basis_cents, :manual_premium_cents, :deposit_premium_cents, :rate_basis_points, :contact_name, :contact_email, :contact_phone, :certificate_url, :coverage_active, :renewal_due) do
    def self.from_record(record)
      return unless record

      new(
        id: record.id,
        carrier: record.carrier,
        policy_number: record.policy_number,
        status: record.status,
        coverage_start_on: record.coverage_start_on,
        coverage_end_on: record.coverage_end_on,
        renewal_due_on: record.renewal_due_on,
        payroll_basis_cents: record.payroll_basis_cents,
        manual_premium_cents: record.manual_premium_cents,
        deposit_premium_cents: record.deposit_premium_cents,
        rate_basis_points: record.rate_basis_points,
        contact_name: record.contact_name,
        contact_email: record.contact_email,
        contact_phone: record.contact_phone,
        certificate_url: record.certificate_url,
        coverage_active: record.coverage_active?,
        renewal_due: record.renewal_due?
      )
    end
  end
end
