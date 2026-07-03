module PayStatements
  class CenterQuery
    def initialize(employer_repository: Employers::EmployerRepository.new)
      @employer = employer_repository.first_for_operations
      @repository = StatementRepository.new(employer: @employer)
    end

    def call
      statement_records = @repository.statements.to_a
      payroll_detail = payroll_detail_for(@repository.current_run)
      batches = @repository.batches
      latest_batch = batches.first.to_h

      CenterDto.new(
        employer: Operations::EmployerContextDto.from_record(@employer),
        metrics: metrics(statement_records, payroll_detail),
        payroll_run: PayrollRunDto.from_payroll_detail(payroll_detail),
        statements: statement_records.map { |statement| StatementDto.from_record(statement) },
        delivery_issues: delivery_issues(statement_records, payroll_detail),
        batches: batches.map { |payload| BatchDto.from_hash(payload) },
        batch_lines: latest_batch.fetch("statements", []).map { |payload| BatchLineDto.from_hash(payload) },
        batch_holdbacks: latest_batch.fetch("holdbacks", []).map { |payload| BatchHoldbackDto.from_hash(payload) },
        batch_payload: batches.first
      )
    end

    private

    def payroll_detail_for(run)
      Payroll::RunDetailDto.from_record(run) if run
    end

    def metrics(statements, payroll_detail)
      generated_count = statements.count(&:generated?)
      delivered_count = statements.count(&:delivered?)
      viewed_count = statements.count(&:viewed?)
      net_pay_cents = payroll_detail&.estimated_net_pay_cents.to_i

      [
        MetricDto.new(label: "Generated", value: generated_count, hint: "waiting for employee delivery", status: generated_count.positive? ? "needs_review" : "ready", accent: "bg-indigo-500", format: "number"),
        MetricDto.new(label: "Delivered", value: delivered_count, hint: "#{viewed_count} viewed by employees", status: delivered_count.positive? ? "ready" : "needs_review", accent: "bg-emerald-500", format: "number"),
        MetricDto.new(label: "Current run net", value: net_pay_cents, hint: payroll_detail ? "expected statement net pay" : "no current payroll run", status: payroll_detail ? "ready" : "blocked", accent: "bg-sky-500", format: "money"),
        MetricDto.new(label: "Employee lines", value: payroll_detail&.employee_count.to_i, hint: "current payroll recipients", status: payroll_detail&.employee_count.to_i.positive? ? "ready" : "needs_review", accent: "bg-fuchsia-500", format: "number")
      ]
    end

    def delivery_issues(statements, payroll_detail)
      routes = Rails.application.routes.url_helpers
      items = []
      generated = statements.select(&:generated?)
      missing_count = payroll_detail ? [ payroll_detail.employee_count - statements.count { |statement| statement.payroll_run_id == payroll_detail.id }, 0 ].max : 0
      voided = statements.select(&:void?)

      if payroll_detail.blank?
        items << DeliveryIssueDto.new(key: "missing_payroll_run", title: "Create a payroll run", detail: "A payroll run is required before employee pay statements can be generated.", severity: "high", status: "blocked", owner: "Payroll", count: 1, amount_cents: 0, action_path: routes.payroll_path)
      end

      if missing_count.positive?
        items << DeliveryIssueDto.new(key: "missing_statements", title: "Generate current pay statements", detail: "#{missing_count} employees in the current run do not have a generated wage statement yet.", severity: "medium", status: "needs_review", owner: "Payroll", count: missing_count, amount_cents: payroll_detail&.estimated_net_pay_cents.to_i, action_path: routes.generate_pay_statement_batch_path)
      end

      if generated.any?
        items << DeliveryIssueDto.new(key: "delivery_queue", title: "Deliver generated statements", detail: "#{generated.count} generated statements are waiting to be delivered to employee portals.", severity: "medium", status: "needs_review", owner: "People Ops", count: generated.count, amount_cents: generated.sum(&:net_pay_cents), action_path: routes.pay_statements_path)
      end

      if voided.any?
        items << DeliveryIssueDto.new(key: "voided_statements", title: "Review voided statements", detail: "#{voided.count} statements are void and should be regenerated or documented before payroll close.", severity: "high", status: "blocked", owner: "Payroll", count: voided.count, amount_cents: voided.sum(&:net_pay_cents), action_path: routes.pay_statements_path)
      end

      return items if items.any?

      [
        DeliveryIssueDto.new(key: "statements_ready", title: "Pay statements are delivered", detail: "Current statement generation and employee delivery queues are clear.", severity: "low", status: "ready", owner: "Payroll", count: statements.count, amount_cents: statements.sum(&:net_pay_cents), action_path: routes.pay_statements_path)
      ]
    end
  end
end
