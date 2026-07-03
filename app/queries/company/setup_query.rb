module Company
  class SetupQuery
    def initialize(employer_repository: Employers::EmployerRepository.new)
      @employer = employer_repository.first_for_operations
      @repository = SetupRepository.new(employer: @employer)
    end

    def call
      departments = @repository.departments.to_a
      locations = @repository.locations.to_a
      employees = @repository.employees.to_a
      benefit_plans = @repository.benefit_plans.to_a
      payroll_runs = @repository.payroll_runs.to_a
      compliance_cases = @repository.compliance_cases.to_a
      integration = IntegrationReadinessDto.from_record(@repository.vitable_connection)
      steps = steps_for(departments, locations, employees, benefit_plans, payroll_runs, compliance_cases, integration)

      SetupDetailDto.new(
        employer: Operations::EmployerContextDto.from_record(@employer),
        organization_name: @employer.organization.name,
        legal_name: @employer.legal_name,
        ein: @employer.ein,
        status: @employer.status,
        onboarded_at: @employer.onboarded_at,
        launch_progress: launch_progress(steps),
        metrics: metrics(departments, locations, employees, benefit_plans, payroll_runs, compliance_cases),
        steps:,
        payroll_settings: payroll_settings,
        departments: departments.map { |department| OrgUnitDto.from_record(department) },
        locations: locations.map { |location| LocationCoverageDto.from_record(location) },
        integration:,
        coverage: coverage(employees, benefit_plans, payroll_runs, compliance_cases)
      )
    end

    private

    def steps_for(departments, locations, employees, benefit_plans, payroll_runs, compliance_cases, integration)
      completed = @repository.completed_steps
      [
        step(
          completed:,
          key: "legal_entity",
          label: "Legal entity",
          description: "Company name, EIN, and operating status are ready for payroll and benefits contracts.",
          detail: @employer.legal_name.present? && @employer.ein.present? ? "Legal entity data is present" : "Legal name or EIN still needs review",
          computed_complete: @employer.legal_name.present? && @employer.ein.present?,
          critical: true
        ),
        step(
          completed:,
          key: "organization_structure",
          label: "Departments and locations",
          description: "Org structure can support managers, payroll taxes, and worker assignment.",
          detail: "#{departments.count} departments and #{locations.count} locations configured",
          computed_complete: departments.any? && locations.any?,
          critical: true
        ),
        step(
          completed:,
          key: "workforce_roster",
          label: "Workforce roster",
          description: "Active employees have compensation, department, and location coverage.",
          detail: "#{payroll_ready_count(employees)}/#{employees.count} employees payroll-ready",
          computed_complete: employees.any? && payroll_ready_count(employees) == employees.count,
          critical: true
        ),
        step(
          completed:,
          key: "payroll_settings",
          label: "Payroll settings",
          description: "Pay frequency, payroll provider, and first run are configured.",
          detail: "#{setting_value('pay_frequency', 'Pay frequency pending')} · #{payroll_runs.count} payroll runs",
          computed_complete: setting_value("pay_frequency").present? && setting_value("payroll_provider").present? && payroll_runs.any?,
          critical: true
        ),
        step(
          completed:,
          key: "benefits_configuration",
          label: "Benefits configuration",
          description: "Plan catalog and enrollment strategy are ready for Vitable-backed benefits.",
          detail: "#{benefit_plans.count} plans · #{setting_value('enrollment_widget', 'Widget pending')}",
          computed_complete: benefit_plans.any? && setting_value("enrollment_widget").present?,
          critical: true
        ),
        step(
          completed:,
          key: "compliance_readiness",
          label: "Compliance readiness",
          description: "Open compliance cases and document exceptions are visible before launch.",
          detail: "#{open_case_count(compliance_cases)} open cases · #{document_attention_count(employees)} document issues",
          computed_complete: open_case_count(compliance_cases).zero? && document_attention_count(employees).zero?,
          critical: false
        ),
        step(
          completed:,
          key: "vitable_connection",
          label: "Vitable connection",
          description: "API credentials, webhook secret, and sync status are ready for live integration traffic.",
          detail: integration.connected? ? "Connection is active" : "Connection #{integration.status.humanize.downcase}",
          computed_complete: integration.connected?,
          critical: true
        ),
        step(
          completed:,
          key: "launch_review",
          label: "Launch review",
          description: "Operations lead has reviewed the setup packet and accepted launch risk.",
          detail: completed.key?("launch_review") ? "Launch review acknowledged" : "Awaiting launch review acknowledgement",
          computed_complete: false,
          critical: false
        )
      ]
    end

    def step(completed:, key:, label:, description:, detail:, computed_complete:, critical:)
      manual_completion = completed[key]
      complete = computed_complete || manual_completion.present?

      SetupStepDto.new(
        key:,
        label:,
        description:,
        detail:,
        status: complete ? "complete" : (critical ? "blocked" : "needs_review"),
        critical:,
        completed_at: manual_completion&.fetch("completed_at", nil),
        manual: manual_completion.present? && !computed_complete
      )
    end

    def metrics(departments, locations, employees, benefit_plans, payroll_runs, compliance_cases)
      [
        MetricDto.new(label: "Employees", value: employees.count, hint: "#{payroll_ready_count(employees)} payroll-ready", status: employees.any? ? "ready" : "needs_review", accent: "bg-emerald-500"),
        MetricDto.new(label: "Org units", value: departments.count, hint: "#{locations.count} locations", status: departments.any? && locations.any? ? "ready" : "needs_review", accent: "bg-cyan-500"),
        MetricDto.new(label: "Benefits plans", value: benefit_plans.count, hint: setting_value("contribution_strategy", "Contribution pending").humanize, status: benefit_plans.any? ? "ready" : "needs_review", accent: "bg-indigo-500"),
        MetricDto.new(label: "Open risks", value: open_case_count(compliance_cases), hint: "#{payroll_runs.count} payroll runs", status: open_case_count(compliance_cases).zero? ? "ready" : "needs_review", accent: "bg-amber-500")
      ]
    end

    def payroll_settings
      [
        PayrollSettingDto.new(key: "pay_frequency", label: "Pay frequency", value: setting_value("pay_frequency", "Not configured"), status: setting_value("pay_frequency").present? ? "ready" : "needs_review"),
        PayrollSettingDto.new(key: "payroll_provider", label: "Payroll provider", value: setting_value("payroll_provider", "Not configured"), status: setting_value("payroll_provider").present? ? "ready" : "needs_review"),
        PayrollSettingDto.new(key: "contribution_strategy", label: "Contribution strategy", value: setting_value("contribution_strategy", "Not configured"), status: setting_value("contribution_strategy").present? ? "ready" : "needs_review"),
        PayrollSettingDto.new(key: "enrollment_widget", label: "Enrollment widget", value: setting_value("enrollment_widget", "Not configured"), status: setting_value("enrollment_widget").present? ? "ready" : "needs_review")
      ]
    end

    def coverage(employees, benefit_plans, payroll_runs, compliance_cases)
      {
        payroll_ready: payroll_ready_count(employees),
        document_attention: document_attention_count(employees),
        accepted_enrollments: employees.sum { |employee| employee.enrollments.count { |enrollment| enrollment.status == "accepted" } },
        benefit_plan_count: benefit_plans.count,
        payroll_run_count: payroll_runs.count,
        open_case_count: open_case_count(compliance_cases)
      }
    end

    def launch_progress(steps)
      return 0 if steps.empty?

      ((steps.count(&:complete?).to_f / steps.count) * 100).round
    end

    def payroll_ready_count(employees)
      employees.count { |employee| employee.compensation_cents.positive? && employee.department.present? && employee.work_location.present? }
    end

    def document_attention_count(employees)
      employees.sum { |employee| employee.employee_documents.count { |document| %w[pending expired].include?(document.status) } }
    end

    def open_case_count(compliance_cases)
      compliance_cases.count { |compliance_case| compliance_case.status != "resolved" }
    end

    def setting_value(key, fallback = nil)
      @employer.settings.to_h.fetch(key, fallback)
    end
  end
end
