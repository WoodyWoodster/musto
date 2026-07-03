module TimeTracking
  class CenterQuery
    def initialize(employer_repository: Employers::EmployerRepository.new)
      @employer = employer_repository.first_for_operations
      @repository = TimeTrackingRepository.new(employer: @employer)
    end

    def call
      entries = @repository.entries.to_a
      employees = @repository.employees.to_a
      departments = @repository.departments.to_a
      exports = @repository.exports

      CenterDto.new(
        employer: Operations::EmployerContextDto.from_record(@employer),
        metrics: metrics(entries, employees),
        entries: entries.map { |entry| EntryDto.from_record(entry) },
        employees: employee_summaries(employees, entries),
        departments: department_summaries(departments, entries),
        exceptions: exceptions(entries, employees),
        exports: exports.map { |payload| ExportDto.from_hash(payload) },
        export_payload: exports.first
      )
    end

    private

    def metrics(entries, employees)
      approved_minutes = entries.select(&:approved?).sum(&:duration_minutes)
      submitted_count = entries.count(&:submitted?)
      overtime_minutes = employee_summaries(employees, entries).sum(&:overtime_minutes)

      [
        MetricDto.new(label: "Approved hours", value: approved_minutes / 60.0, hint: "#{entries.count(&:approved?)} approved entries", status: approved_minutes.positive? ? "ready" : "needs_review", accent: "bg-emerald-500", format: "hours"),
        MetricDto.new(label: "Review queue", value: submitted_count, hint: "submitted entries", status: submitted_count.positive? ? "needs_review" : "ready", accent: "bg-amber-500", format: "number"),
        MetricDto.new(label: "Overtime hours", value: overtime_minutes / 60.0, hint: "weekly threshold exposure", status: overtime_minutes.positive? ? "needs_review" : "ready", accent: "bg-indigo-500", format: "hours"),
        MetricDto.new(label: "Coverage", value: employees.count { |employee| entries.any? { |entry| entry.employee_id == employee.id } }, hint: "#{employees.count} active employees", status: "ready", accent: "bg-cyan-500", format: "number")
      ]
    end

    def employee_summaries(employees, entries)
      employees.map do |employee|
        employee_entries = entries.select { |entry| entry.employee_id == employee.id }
        approved_minutes = employee_entries.select(&:approved?).sum(&:duration_minutes)
        submitted_minutes = employee_entries.select(&:submitted?).sum(&:duration_minutes)
        overtime_minutes = [ approved_minutes - 2_400, 0 ].max

        EmployeeSummaryDto.new(
          employee_id: employee.id,
          employee_name: employee.full_name,
          department_name: employee.department&.name || "Unassigned",
          pay_type: employee.pay_type,
          entry_count: employee_entries.count,
          approved_minutes: approved_minutes,
          submitted_minutes: submitted_minutes,
          overtime_minutes: overtime_minutes,
          regular_minutes: approved_minutes - overtime_minutes,
          status: employee_status(employee_entries, overtime_minutes)
        )
      end
    end

    def department_summaries(departments, entries)
      departments.map do |department|
        department_entries = entries.select { |entry| entry.employee.department_id == department.id }
        approved_minutes = department_entries.select(&:approved?).sum(&:duration_minutes)
        submitted_minutes = department_entries.select(&:submitted?).sum(&:duration_minutes)
        approval_rate = department_entries.any? ? ((department_entries.count(&:approved?).to_f / department_entries.count) * 100).round : 0

        DepartmentSummaryDto.new(
          department_id: department.id,
          department_name: department.name,
          employee_count: department.employees.active.count,
          approved_minutes: approved_minutes,
          submitted_minutes: submitted_minutes,
          overtime_minutes: department_overtime_minutes(department_entries),
          approval_rate: approval_rate,
          status: submitted_minutes.positive? ? "needs_review" : "ready"
        )
      end
    end

    def exceptions(entries, employees)
      routes = Rails.application.routes.url_helpers
      items = []
      submitted_count = entries.count(&:submitted?)
      rejected_count = entries.count(&:rejected?)
      missing_entry_count = employees.count { |employee| entries.none? { |entry| entry.employee_id == employee.id } }
      overtime_count = employee_summaries(employees, entries).count { |summary| summary.overtime_minutes.positive? }

      if submitted_count.positive?
        items << ExceptionDto.new(key: "approval_queue", title: "Approve submitted time", detail: "#{submitted_count} time entries need manager review before payroll export.", severity: "medium", status: "needs_review", owner: "Managers", action_path: routes.timesheets_path)
      end

      if missing_entry_count.positive?
        items << ExceptionDto.new(key: "missing_time", title: "Missing timesheets", detail: "#{missing_entry_count} active employees do not have time entries in the current workspace.", severity: "medium", status: "needs_review", owner: "People", action_path: routes.workforce_path)
      end

      if overtime_count.positive?
        items << ExceptionDto.new(key: "overtime_review", title: "Review overtime exposure", detail: "#{overtime_count} employees have approved hours over the weekly overtime threshold.", severity: "medium", status: "needs_review", owner: "Payroll", action_path: routes.payroll_path)
      end

      if rejected_count.positive?
        items << ExceptionDto.new(key: "rejected_entries", title: "Resolve rejected time", detail: "#{rejected_count} rejected entries need correction before export.", severity: "low", status: "needs_review", owner: "Employees", action_path: routes.timesheets_path)
      end

      return items if items.any?

      [
        ExceptionDto.new(key: "timesheets_ready", title: "Timesheets are payroll-ready", detail: "Approved hours are ready for the next payroll export.", severity: "low", status: "ready", owner: "Payroll", action_path: routes.generate_time_tracking_export_path)
      ]
    end

    def employee_status(entries, overtime_minutes)
      return "needs_review" if entries.any?(&:submitted?)
      return "blocked" if entries.any?(&:rejected?)
      return "needs_review" if overtime_minutes.positive?
      return "ready" if entries.any?

      "pending"
    end

    def department_overtime_minutes(entries)
      entries.group_by(&:employee_id).sum do |_employee_id, employee_entries|
        [ employee_entries.select(&:approved?).sum(&:duration_minutes) - 2_400, 0 ].max
      end
    end
  end
end
