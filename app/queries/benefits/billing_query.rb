module Benefits
  class BillingQuery
    def initialize(employer_repository: Employers::EmployerRepository.new)
      @employer = employer_repository.first_for_operations
      @repository = BillingRepository.new(employer: @employer)
    end

    def call
      invoices = @repository.invoices.to_a
      lines = @repository.invoice_lines.to_a
      packets = @repository.packets
      latest_packet = packets.first.to_h

      BillingCenterDto.new(
        employer: Operations::EmployerContextDto.from_record(@employer),
        metrics: metrics(invoices, lines),
        invoices: invoices.map { |invoice| BillingInvoiceDto.from_record(invoice) },
        lines: lines.map { |line| BillingLineDto.from_record(line) },
        variances: variances(invoices, lines),
        packets: packets.map { |payload| BillingPacketDto.from_hash(payload) },
        packet_lines: latest_packet.fetch("payments", []).map { |payload| BillingPacketLineDto.from_hash(payload) },
        packet_holdbacks: latest_packet.fetch("holdbacks", []).map { |payload| BillingPacketHoldbackDto.from_hash(payload) },
        packet_payload: packets.first
      )
    end

    private

    def metrics(invoices, lines)
      open_invoices = invoices.reject(&:paid?)
      total_premium_cents = open_invoices.sum(&:total_premium_cents)
      employee_contribution_cents = open_invoices.sum(&:employee_contribution_cents)
      variance_cents = lines.sum { |line| line.variance_cents.abs }
      holdback_count = lines.count(&:blocked?)

      [
        BillingMetricDto.new(label: "Open invoices", value: open_invoices.count, hint: "#{invoices.count} carrier invoices tracked", status: open_invoices.any? ? "needs_review" : "ready", accent: "bg-cyan-500", format: "number"),
        BillingMetricDto.new(label: "Premium exposure", value: total_premium_cents, hint: "current unpaid Vitable premiums", status: total_premium_cents.positive? ? "needs_review" : "ready", accent: "bg-indigo-500", format: "money"),
        BillingMetricDto.new(label: "Payroll collections", value: employee_contribution_cents, hint: "employee contribution recovered through payroll", status: employee_contribution_cents.positive? ? "ready" : "needs_review", accent: "bg-emerald-500", format: "money"),
        BillingMetricDto.new(label: "Variance holdbacks", value: holdback_count, hint: variance_cents.positive? ? "#{variance_cents} cents in premium variance" : "invoice lines match local plan premiums", status: holdback_count.positive? ? "needs_review" : "ready", accent: "bg-amber-500", format: "number")
      ]
    end

    def variances(invoices, lines)
      routes = Rails.application.routes.url_helpers
      items = []
      open_invoices = invoices.reject(&:paid?)
      overdue = open_invoices.select { |invoice| invoice.due_on < Date.current }
      variance_lines = lines.select { |line| line.variance_cents != 0 }
      missing_deductions = lines.select { |line| line.status == "missing_deduction" }
      review_lines = lines.select { |line| line.status == "needs_review" }

      if overdue.any?
        items << BillingVarianceDto.new(key: "overdue_invoices", title: "Approve overdue benefit invoices", detail: "#{overdue.count} Vitable benefit invoices are past due and need payment review.", severity: "critical", status: "blocked", owner: "Finance", count: overdue.count, amount_cents: overdue.sum(&:total_premium_cents), action_path: routes.benefits_billing_path)
      end

      if variance_lines.any?
        items << BillingVarianceDto.new(key: "premium_variance", title: "Investigate premium variance", detail: "#{variance_lines.count} invoice lines differ from local plan premiums and should be reviewed before payment.", severity: "high", status: "needs_review", owner: "Benefits", count: variance_lines.count, amount_cents: variance_lines.sum(&:variance_cents).abs, action_path: routes.benefits_billing_path)
      end

      if missing_deductions.any?
        items << BillingVarianceDto.new(key: "missing_payroll_deductions", title: "Repair missing payroll deductions", detail: "#{missing_deductions.count} accepted enrollments are billed but missing ready payroll deductions.", severity: "high", status: "blocked", owner: "Payroll", count: missing_deductions.count, amount_cents: missing_deductions.sum(&:amount_cents), action_path: routes.benefits_reconciliation_path)
      end

      if review_lines.any?
        items << BillingVarianceDto.new(key: "enrollment_review", title: "Review billed enrollment state", detail: "#{review_lines.count} billed enrollment lines are not accepted locally.", severity: "medium", status: "needs_review", owner: "People Ops", count: review_lines.count, amount_cents: review_lines.sum(&:amount_cents), action_path: routes.benefits_path)
      end

      return items if items.any?

      [
        BillingVarianceDto.new(key: "billing_ready", title: "Benefit billing is payment-ready", detail: "Carrier invoice premiums, payroll deductions, and employer contribution math are aligned.", severity: "low", status: "ready", owner: "Finance", count: lines.count, amount_cents: open_invoices.sum(&:total_premium_cents), action_path: routes.generate_benefit_billing_packet_path)
      ]
    end
  end
end
