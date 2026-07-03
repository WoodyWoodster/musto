module Compensation
  class CenterQuery
    def initialize(employer_repository: Employers::EmployerRepository.new)
      @employer = employer_repository.first_for_operations
      @repository = CompensationRepository.new(employer: @employer)
    end

    def call
      employees = @repository.employees.to_a
      departments = @repository.departments.to_a
      adjustments = @repository.payroll_adjustments.to_a
      packets = @repository.packets
      employee_dtos = employees.map { |employee| employee_compensation(employee, adjustments) }
      department_dtos = departments.map { |department| department_budget(department, employees, adjustments) }

      CenterDto.new(
        employer: Operations::EmployerContextDto.from_record(@employer),
        metrics: metrics(employee_dtos, department_dtos, adjustments),
        employees: employee_dtos,
        departments: department_dtos,
        adjustments: adjustments.map { |adjustment| adjustment_detail(adjustment) },
        recommendations: recommendations(employee_dtos, department_dtos, adjustments),
        packets: packets.map { |payload| PacketDto.from_hash(payload) },
        packet_payload: packets.first
      )
    end

    private

    def metrics(employees, departments, adjustments)
      annual_payroll_cents = employees.sum(&:base_compensation_cents)
      adjustment_cents = adjustments.sum(&:amount_cents)
      remaining_budget_cents = departments.sum(&:remaining_cents)
      review_queue = employees.count { |employee| employee.status != "ready" } + departments.count { |department| department.status != "ready" }

      [
        MetricDto.new(label: "Annual payroll", value: annual_payroll_cents, hint: "#{employees.count} active employees", status: annual_payroll_cents.positive? ? "ready" : "needs_review", accent: "bg-indigo-500", format: "money"),
        MetricDto.new(label: "Planned adjustments", value: adjustment_cents, hint: "#{adjustments.count} adjustment lines", status: adjustments.any? ? "needs_review" : "ready", accent: "bg-emerald-500", format: "money"),
        MetricDto.new(label: "Budget remaining", value: remaining_budget_cents, hint: "#{departments.count} departments", status: departments.any? { |department| department.status == "blocked" } ? "blocked" : "ready", accent: "bg-cyan-500", format: "money"),
        MetricDto.new(label: "Review queue", value: review_queue, hint: "employees and departments", status: review_queue.positive? ? "needs_review" : "ready", accent: "bg-amber-500", format: "number")
      ]
    end

    def employee_compensation(employee, adjustments)
      accepted_enrollments = employee.enrollments.select { |enrollment| enrollment.status == "accepted" }
      pending_enrollment_count = employee.enrollments.count { |enrollment| enrollment.status == "pending" }
      monthly_benefit_cents = accepted_enrollments.sum { |enrollment| enrollment.benefit_plan.monthly_premium_cents }
      adjustment_cents = adjustments.select { |adjustment| adjustment.employee_id == employee.id }.sum(&:amount_cents)
      status, status_reason = employee_status(employee, accepted_enrollments, pending_enrollment_count)

      EmployeeCompensationDto.new(
        employee_id: employee.id,
        employee_name: employee.full_name,
        title: employee.title,
        department_name: employee.department&.name || "Unassigned",
        location_name: employee.work_location&.name || "Missing location",
        pay_type: employee.pay_type,
        base_compensation_cents: employee.compensation_cents,
        monthly_benefit_cents: monthly_benefit_cents,
        annual_benefit_cents: monthly_benefit_cents * 12,
        adjustment_cents: adjustment_cents,
        total_planned_cents: employee.compensation_cents + adjustment_cents + (monthly_benefit_cents * 12),
        accepted_enrollment_count: accepted_enrollments.count,
        pending_enrollment_count: pending_enrollment_count,
        status: status,
        status_reason: status_reason
      )
    end

    def department_budget(department, employees, adjustments)
      department_employees = employees.select { |employee| employee.department_id == department.id }
      base_compensation_cents = department_employees.sum(&:compensation_cents)
      adjustment_cents = adjustments.select { |adjustment| adjustment.employee.department_id == department.id }.sum(&:amount_cents)
      annual_benefit_cents = department_employees.sum { |employee| accepted_benefit_cost_cents(employee) * 12 }
      planned_spend_cents = base_compensation_cents + adjustment_cents + annual_benefit_cents
      remaining_cents = department.budget_cents - planned_spend_cents
      utilization_percent = department.budget_cents.positive? ? (planned_spend_cents.to_f / department.budget_cents * 100).round : 0

      DepartmentBudgetDto.new(
        department_id: department.id,
        department_name: department.name,
        code: department.code,
        employee_count: department_employees.count,
        budget_cents: department.budget_cents,
        base_compensation_cents: base_compensation_cents,
        adjustment_cents: adjustment_cents,
        annual_benefit_cents: annual_benefit_cents,
        planned_spend_cents: planned_spend_cents,
        remaining_cents: remaining_cents,
        utilization_percent: utilization_percent,
        status: department_status(department.budget_cents, planned_spend_cents, utilization_percent)
      )
    end

    def adjustment_detail(adjustment)
      AdjustmentDto.new(
        id: adjustment.id,
        employee_id: adjustment.employee_id,
        employee_name: adjustment.employee.full_name,
        department_name: adjustment.employee.department&.name || "Unassigned",
        payroll_run_id: adjustment.payroll_run_id,
        pay_date: adjustment.payroll_run.pay_date,
        adjustment_type: adjustment.adjustment_type,
        description: adjustment.description,
        amount_cents: adjustment.amount_cents,
        taxable: adjustment.taxable?,
        status: adjustment.amount_cents.negative? ? "needs_review" : "ready"
      )
    end

    def recommendations(employees, departments, adjustments)
      items = []
      blocked_employees = employees.select { |employee| employee.status == "blocked" }
      pending_enrollments = employees.sum(&:pending_enrollment_count)
      over_budget = departments.select { |department| department.status == "blocked" }
      budget_pressure = departments.select { |department| department.status == "needs_review" }
      routes = Rails.application.routes.url_helpers

      if blocked_employees.any?
        items << RecommendationDto.new(
          key: "employee_setup",
          title: "Complete employee pay setup",
          detail: "#{blocked_employees.count} employees are missing compensation, department, or work location data.",
          severity: "high",
          status: "blocked",
          owner: "People",
          action_path: routes.workforce_path
        )
      end

      if pending_enrollments.positive?
        items << RecommendationDto.new(
          key: "benefit_alignment",
          title: "Resolve pending benefit elections",
          detail: "#{pending_enrollments} Vitable benefit elections can still change deduction readiness.",
          severity: "medium",
          status: "needs_review",
          owner: "Benefits",
          action_path: routes.benefits_path
        )
      end

      (over_budget + budget_pressure).each do |department|
        items << RecommendationDto.new(
          key: "department_budget_#{department.department_id}",
          title: "Review #{department.department_name} budget exposure",
          detail: "#{department.department_name} is at #{department.utilization_percent}% utilization with #{department.employee_count} employees.",
          severity: department.status == "blocked" ? "high" : "medium",
          status: department.status,
          owner: "Finance",
          action_path: routes.reports_path
        )
      end

      if adjustments.any?
        items << RecommendationDto.new(
          key: "adjustment_review",
          title: "Review payroll adjustments",
          detail: "#{adjustments.count} bonuses, reimbursements, or corrections are included in this planning packet.",
          severity: "medium",
          status: "needs_review",
          owner: "Payroll",
          action_path: routes.payroll_path
        )
      end

      return items if items.any?

      [
        RecommendationDto.new(
          key: "packet_ready",
          title: "Compensation packet is ready",
          detail: "Employees, budgets, benefit load, and payroll adjustments are aligned for finance review.",
          severity: "low",
          status: "ready",
          owner: "Finance",
          action_path: routes.generate_compensation_packet_path
        )
      ]
    end

    def employee_status(employee, accepted_enrollments, pending_enrollment_count)
      blockers = []
      blockers << "missing compensation" unless employee.compensation_cents.positive?
      blockers << "missing department" unless employee.department
      blockers << "missing work location" unless employee.work_location
      return [ "blocked", blockers.to_sentence ] if blockers.any?

      return [ "needs_review", "pending benefit elections" ] if pending_enrollment_count.positive?
      return [ "needs_review", "no accepted Vitable benefit" ] if accepted_enrollments.empty?

      [ "ready", "ready for compensation packet" ]
    end

    def department_status(budget_cents, planned_spend_cents, utilization_percent)
      return "blocked" if planned_spend_cents > budget_cents
      return "needs_review" if utilization_percent >= 90

      "ready"
    end

    def accepted_benefit_cost_cents(employee)
      employee.enrollments.select { |enrollment| enrollment.status == "accepted" }.sum { |enrollment| enrollment.benefit_plan.monthly_premium_cents }
    end
  end
end
