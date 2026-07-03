module Benefits
  ReconciliationDetailDto = Data.define(:employer, :payroll_run, :metrics, :items, :exception_items, :ready_items) do
    def self.from_records(employer:, payroll_run:, enrollments:)
      items = enrollments.map { |enrollment| ReconciliationItemDto.from_record(enrollment) }
      exception_items = items.select(&:exception?)
      ready_items = items.select(&:aligned?)

      new(
        employer: Operations::EmployerContextDto.from_record(employer),
        payroll_run: payroll_run && Operations::PayrollRunDto.from_record(payroll_run),
        metrics: metrics(items, exception_items),
        items:,
        exception_items:,
        ready_items:
      )
    end

    def self.metrics(items, exception_items)
      expected_total = items.sum(&:expected_amount_cents)
      actual_total = items.sum(&:actual_amount_cents)

      [
        ReconciliationMetricDto.new(label: "Enrollments checked", value: items.count, status: "ready"),
        ReconciliationMetricDto.new(label: "Exceptions", value: exception_items.count, status: exception_items.any? ? "needs_review" : "ready"),
        ReconciliationMetricDto.new(label: "Expected deductions", value: expected_total, status: "ready"),
        ReconciliationMetricDto.new(label: "Variance", value: actual_total - expected_total, status: actual_total == expected_total ? "ready" : "needs_review")
      ]
    end

    private_class_method :metrics
  end
end
