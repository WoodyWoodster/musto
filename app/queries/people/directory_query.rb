module People
  class DirectoryQuery
    def initialize(employer_repository: Employers::EmployerRepository.new)
      @employer = employer_repository.first_for_operations
      @repository = DirectoryRepository.new(employer: @employer)
    end

    def call
      roster = @repository.employees.to_a
      employees = roster.map { |employee| employee_node(employee, roster) }
      departments = @repository.departments.map { |department| DepartmentNodeDto.from_record(department) }
      managers = employees.select(&:manager?).map do |employee|
        ManagerSpanDto.new(
          manager_id: employee.employee_id,
          manager_name: employee.employee_name,
          title: employee.title,
          department_name: employee.department_name,
          direct_report_count: employee.direct_report_count,
          status: manager_status(employee.direct_report_count)
        )
      end
      snapshot_payload = @repository.latest_snapshot
      snapshot = snapshot_payload.present? ? DirectorySnapshotDto.from_hash(snapshot_payload) : nil

      DirectoryCenterDto.new(
        employer: Operations::EmployerContextDto.from_record(@employer),
        metrics: metrics(employees, managers, departments, snapshot),
        employees:,
        managers:,
        departments:,
        unassigned_employees: employees.select(&:unassigned?),
        issues: directory_issues(employees, departments),
        snapshot:,
        snapshot_issues: snapshot_payload.to_h.fetch("issues", []).map { |payload| DirectoryIssueDto.from_hash(payload) }
      )
    end

    private

    def employee_node(employee, roster)
      EmployeeNodeDto.from_record(employee, direct_report_count: roster.count { |candidate| candidate.manager_id == employee.id })
    end

    def metrics(employees, managers, departments, snapshot)
      assigned_count = employees.count { |employee| employee.manager_id.present? }
      unassigned_count = employees.count(&:unassigned?)
      org_gap_count = unassigned_count + departments.count { |department| department.manager_id.blank? }

      [
        MetricDto.new(label: "Directory", value: employees.count, hint: "#{assigned_count} reporting assignments", status: employees.any? ? "ready" : "empty", accent: "bg-emerald-500", format: "number"),
        MetricDto.new(label: "Managers", value: managers.count, hint: "#{managers.sum(&:direct_report_count)} direct reports", status: managers.any? ? "ready" : "needs_review", accent: "bg-indigo-500", format: "number"),
        MetricDto.new(label: "Org gaps", value: org_gap_count, hint: "manager and department ownership", status: org_gap_count.positive? ? "needs_review" : "ready", accent: "bg-amber-500", format: "number"),
        MetricDto.new(label: "Snapshot", value: snapshot&.status&.humanize || "Not generated", hint: snapshot ? "#{snapshot.issue_count} issues captured" : "generate for audit trail", status: snapshot&.status || "pending", accent: "bg-cyan-500", format: "text")
      ]
    end

    def directory_issues(employees, departments)
      issues = []
      employees.select(&:unassigned?).each do |employee|
        issues << DirectoryIssueDto.new(employee_id: employee.employee_id, employee_name: employee.employee_name, department_name: employee.department_name, status: "needs_review", reason_code: "missing_manager", reason: "Employee has no manager assignment.")
      end
      departments.select { |department| department.manager_id.blank? }.each do |department|
        issues << DirectoryIssueDto.new(employee_id: nil, employee_name: department.department_name, department_name: department.department_name, status: "needs_review", reason_code: "missing_department_manager", reason: "Department has no manager assigned.")
      end
      issues
    end

    def manager_status(direct_report_count)
      return "blocked" if direct_report_count > 8
      return "needs_review" if direct_report_count > 5

      "ready"
    end
  end
end
