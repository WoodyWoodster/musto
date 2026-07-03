module WorkersComp
  ExposureDto = Data.define(:class_code, :class_description, :service_state, :employee_count, :employee_names, :payroll_cents, :rate_basis_points, :estimated_premium_cents) do
    def self.from_hash(payload)
      attributes = payload.to_h.stringify_keys

      new(
        class_code: attributes.fetch("class_code"),
        class_description: attributes.fetch("class_description"),
        service_state: attributes.fetch("service_state"),
        employee_count: attributes.fetch("employee_count", 0),
        employee_names: attributes.fetch("employee_names", []),
        payroll_cents: attributes.fetch("payroll_cents", 0),
        rate_basis_points: attributes.fetch("rate_basis_points", 0),
        estimated_premium_cents: attributes.fetch("estimated_premium_cents", 0)
      )
    end
  end
end
