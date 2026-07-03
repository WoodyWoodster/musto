module Deductions
  class CenterQuery
    def initialize(employer_repository: Employers::EmployerRepository.new)
      @employer = employer_repository.first_for_operations
      @repository = DeductionRepository.new(employer: @employer)
    end

    def call
      deductions = @repository.deductions.to_a
      run = @repository.current_run
      batches = @repository.batches
      latest_batch = batches.first.to_h

      CenterDto.new(
        employer: Operations::EmployerContextDto.from_record(@employer),
        payroll_run: PayrollRunDto.from_record(run),
        metrics: metrics(deductions, run),
        deductions: deductions.map { |deduction| DeductionDto.from_record(deduction, gross_cents: gross_for(deduction), pay_date: run&.pay_date || Date.current) },
        issues: issues(deductions, run),
        packets: batches.map { |payload| PacketDto.from_hash(payload) },
        packet_lines: latest_batch.fetch("lines", []).map { |payload| PacketLineDto.from_hash(payload) },
        packet_holdbacks: latest_batch.fetch("holdbacks", []).map { |payload| PacketHoldbackDto.from_hash(payload) },
        packet_payload: batches.first
      )
    end

    private

    def metrics(deductions, run)
      active = deductions.count(&:active?)
      pending = deductions.count { |deduction| deduction.pending? || deduction.blocked? }
      garnishments = deductions.count(&:garnishment?)
      run_impact = run ? deductions.select { |deduction| deduction.ready_for_payroll?(pay_date: run.pay_date) }.sum { |deduction| deduction.estimated_amount_for(gross_for(deduction), pay_date: run.pay_date) } : 0

      [
        MetricDto.new(label: "Active orders", value: active, hint: "#{deductions.count} recurring deductions tracked", status: active.positive? ? "active" : "needs_review", accent: "bg-rose-500", format: "number"),
        MetricDto.new(label: "Run impact", value: run_impact, hint: run ? "estimated for #{run.pay_date.strftime("%b %-d")}" : "no payroll run available", status: run_impact.positive? ? "withheld" : "pending", accent: "bg-indigo-500", format: "money"),
        MetricDto.new(label: "Garnishments", value: garnishments, hint: "court or agency orders", status: garnishments.positive? ? "active" : "ready", accent: "bg-amber-500", format: "number"),
        MetricDto.new(label: "Needs review", value: pending, hint: "pending or blocked orders", status: pending.positive? ? "needs_review" : "ready", accent: "bg-cyan-500", format: "number")
      ]
    end

    def issues(deductions, run)
      routes = Rails.application.routes.url_helpers
      items = []
      pending = deductions.select(&:pending?)
      blocked = deductions.select(&:blocked?)
      paused = deductions.select(&:paused?)
      ready = run ? deductions.select { |deduction| deduction.ready_for_payroll?(pay_date: run.pay_date) } : []
      large_withholding = ready.select { |deduction| deduction.estimated_amount_for(gross_for(deduction), pay_date: run.pay_date) > (gross_for(deduction) * 0.25) }

      if pending.any?
        items << IssueDto.new(key: "pending_approval", title: "Approve pending deduction orders", detail: "#{pluralized_count(pending.count, "deduction order")} #{be_verb(pending.count)} waiting on payroll approval before the next run.", severity: "high", status: "needs_review", owner: "Payroll", count: pending.count, amount_cents: pending.sum(&:amount_cents), action_path: routes.payroll_deductions_center_path)
      end

      if blocked.any?
        items << IssueDto.new(key: "blocked_orders", title: "Resolve blocked orders", detail: "#{pluralized_count(blocked.count, "order")} #{need_verb(blocked.count)} court, agency, or employee documentation before withholding.", severity: "high", status: "blocked", owner: "Compliance", count: blocked.count, amount_cents: blocked.sum(&:amount_cents), action_path: routes.documents_path)
      end

      if large_withholding.any?
        items << IssueDto.new(key: "net_pay_risk", title: "Review high withholding impact", detail: "#{pluralized_count(large_withholding.count, "deduction")} #{exceed_verb(large_withholding.count)} 25% of modeled gross pay for the employee.", severity: "medium", status: "needs_review", owner: "Payroll", count: large_withholding.count, amount_cents: large_withholding.sum { |deduction| deduction.estimated_amount_for(gross_for(deduction), pay_date: run.pay_date) }, action_path: routes.payroll_deductions_center_path)
      end

      if ready.any?
        items << IssueDto.new(key: "packet_ready", title: "Generate deduction packet", detail: "#{pluralized_count(ready.count, "active order")} #{be_verb(ready.count)} ready to create payroll-run deduction lines.", severity: "medium", status: "ready", owner: "Payroll", count: ready.count, amount_cents: ready.sum { |deduction| deduction.estimated_amount_for(gross_for(deduction), pay_date: run.pay_date) }, action_path: routes.payroll_deductions_center_path)
      end

      if paused.any?
        items << IssueDto.new(key: "paused_orders", title: "Paused orders excluded", detail: "#{pluralized_count(paused.count, "deduction")} will be held out of payroll packets until resumed.", severity: "low", status: "paused", owner: "Payroll", count: paused.count, amount_cents: paused.sum(&:amount_cents), action_path: routes.payroll_deductions_center_path)
      end

      return items if items.any?

      [
        IssueDto.new(key: "deductions_ready", title: "Deduction program is clear", detail: "Recurring deductions, garnishments, and payroll packets have no current blockers.", severity: "low", status: "ready", owner: "Payroll", count: deductions.count, amount_cents: 0, action_path: routes.payroll_deductions_center_path)
      ]
    end

    def gross_for(deduction)
      deduction.employee.compensation_cents / 24
    end

    def pluralized_count(count, noun)
      "#{count} #{noun.pluralize(count)}"
    end

    def be_verb(count)
      count == 1 ? "is" : "are"
    end

    def need_verb(count)
      count == 1 ? "needs" : "need"
    end

    def exceed_verb(count)
      count == 1 ? "exceeds" : "exceed"
    end
  end
end
