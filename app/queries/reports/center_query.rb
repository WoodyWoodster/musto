module Reports
  class CenterQuery
    def initialize(employer_repository: Employers::EmployerRepository.new)
      @employer = employer_repository.first_for_operations
      @repository = ReportsRepository.new(employer: @employer)
    end

    def call
      employees = @repository.employees.to_a
      departments = @repository.departments.to_a
      benefit_plans = @repository.benefit_plans.to_a
      payroll_runs = @repository.payroll_runs.to_a
      deductions = @repository.payroll_deductions.to_a
      compliance_cases = @repository.compliance_cases.to_a
      time_off_requests = @repository.time_off_requests.to_a
      snapshots = @repository.snapshots

      CenterDto.new(
        employer: Operations::EmployerContextDto.from_record(@employer),
        metrics: metrics(employees, benefit_plans, payroll_runs, deductions, compliance_cases, time_off_requests),
        report_cards: report_cards(compliance_cases),
        department_costs: department_costs(departments, employees, deductions, compliance_cases),
        benefit_spend: benefit_plans.map { |plan| BenefitSpendDto.from_record(plan) },
        risk_items: risk_items(employees, compliance_cases, time_off_requests),
        snapshots: snapshots.map { |payload| SnapshotDto.from_hash(payload) },
        snapshot_payload: snapshots.first
      )
    end

    private

    def metrics(employees, benefit_plans, payroll_runs, deductions, compliance_cases, time_off_requests)
      [
        MetricDto.new(label: "Gross payroll", value: payroll_runs.sum(&:gross_pay_cents), hint: "#{payroll_runs.count} runs", status: payroll_runs.any? ? "ready" : "needs_review", accent: "bg-indigo-500", format: "money"),
        MetricDto.new(label: "Benefits cost", value: monthly_benefits_cost_cents(benefit_plans), hint: "monthly accepted premium", status: benefit_plans.any? ? "ready" : "needs_review", accent: "bg-cyan-500", format: "money"),
        MetricDto.new(label: "Ready deductions", value: deductions.select { |deduction| deduction.status == "ready" }.sum(&:amount_cents), hint: "#{deductions.count} deduction lines", status: deductions.any? ? "ready" : "needs_review", accent: "bg-emerald-500", format: "money"),
        MetricDto.new(label: "Open risk", value: open_risk_count(employees, compliance_cases, time_off_requests), hint: "docs, cases, and PTO", status: open_risk_count(employees, compliance_cases, time_off_requests).positive? ? "needs_review" : "ready", accent: "bg-amber-500", format: "number")
      ]
    end

    def report_cards(compliance_cases)
      [
        ReportCardDto.new(key: "payroll_register", title: "Payroll register", description: "Gross payroll, deductions, adjustments, and run status for finance review.", value: "Payroll", status: "ready", cadence: "Per run", owner: "Finance", path: Rails.application.routes.url_helpers.payroll_path),
        ReportCardDto.new(key: "benefits_cost", title: "Benefits cost summary", description: "Accepted enrollment cost by Vitable plan, category, and employee participation.", value: "Benefits", status: "ready", cadence: "Monthly", owner: "Benefits", path: Rails.application.routes.url_helpers.benefits_path),
        ReportCardDto.new(key: "headcount", title: "Headcount and org costs", description: "Department-level headcount, compensation coverage, and benefit spend.", value: "Workforce", status: "ready", cadence: "Live", owner: "People", path: Rails.application.routes.url_helpers.workforce_path),
        ReportCardDto.new(key: "compliance_risk", title: "Compliance risk", description: "Cases, document exceptions, and pending leave review that can block operations.", value: "#{compliance_cases.count { |item| item.status != "resolved" }} open", status: compliance_cases.any? { |item| item.status != "resolved" } ? "needs_review" : "ready", cadence: "Daily", owner: "Operations", path: Rails.application.routes.url_helpers.compliance_path)
      ]
    end

    def department_costs(departments, employees, deductions, compliance_cases)
      departments.map do |department|
        department_employees = employees.select { |employee| employee.department_id == department.id }
        DepartmentCostDto.new(
          department_id: department.id,
          department_name: department.name,
          employee_count: department_employees.count,
          payroll_cents: department_employees.sum(&:compensation_cents),
          benefit_cost_cents: department_employees.sum { |employee| accepted_benefit_cost_cents(employee) },
          deduction_cents: deductions.select { |deduction| deduction.employee.department_id == department.id && deduction.status == "ready" }.sum(&:amount_cents),
          risk_count: compliance_cases.count { |compliance_case| compliance_case.employee&.department_id == department.id && compliance_case.status != "resolved" },
          status: department_employees.any? ? "ready" : "needs_review"
        )
      end
    end

    def risk_items(employees, compliance_cases, time_off_requests)
      document_attention = employees.sum { |employee| employee.employee_documents.count { |document| %w[pending expired].include?(document.status) } }
      urgent_cases = compliance_cases.count { |item| item.status != "resolved" && %w[critical high].include?(item.severity) }
      pending_time_off = time_off_requests.count { |request| request.status == "requested" }

      [
        RiskItemDto.new(label: "Document exceptions", value: document_attention, detail: "Pending or expired employee documents", status: document_attention.positive? ? "needs_review" : "ready", severity: document_attention.positive? ? "medium" : "low"),
        RiskItemDto.new(label: "Urgent compliance", value: urgent_cases, detail: "Critical or high severity open cases", status: urgent_cases.positive? ? "blocked" : "ready", severity: urgent_cases.positive? ? "high" : "low"),
        RiskItemDto.new(label: "PTO review queue", value: pending_time_off, detail: "Pending requests that affect staffing and payroll", status: pending_time_off.positive? ? "needs_review" : "ready", severity: pending_time_off.positive? ? "medium" : "low")
      ]
    end

    def accepted_benefit_cost_cents(employee)
      employee.enrollments.select { |enrollment| enrollment.status == "accepted" }.sum { |enrollment| enrollment.benefit_plan.monthly_premium_cents }
    end

    def monthly_benefits_cost_cents(benefit_plans)
      benefit_plans.sum { |plan| plan.enrollments.count { |enrollment| enrollment.status == "accepted" } * plan.monthly_premium_cents }
    end

    def open_risk_count(employees, compliance_cases, time_off_requests)
      employees.sum { |employee| employee.employee_documents.count { |document| %w[pending expired].include?(document.status) } } +
        compliance_cases.count { |item| item.status != "resolved" } +
        time_off_requests.count { |request| request.status == "requested" }
    end
  end
end
