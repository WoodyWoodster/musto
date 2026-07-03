module People
  class DirectoryRepository < ApplicationRepository
    SNAPSHOT_KEY = "people_directory_snapshot"

    def initialize(employer:)
      @employer = employer
    end

    def employees
      return Employee.none unless @employer

      @employer
        .employees
        .active
        .includes(:department, :work_location, :manager, :direct_reports, enrollments: [ :benefit_plan ])
        .order(:last_name, :first_name)
    end

    def departments
      return Department.none unless @employer

      @employer.departments.includes(:manager, :employees).order(:name)
    end

    def find_employee(id)
      employees.find(id)
    end

    def find_manager(id)
      employees.find(id)
    end

    def latest_snapshot
      @employer&.settings.to_h.fetch(SNAPSHOT_KEY, nil)
    end

    def assign_manager(employee, manager:, assigned_by:)
      return false if employee.id == manager.id

      employee.update!(
        manager:,
        metadata: employee.metadata.to_h.merge(
          "manager_assigned_by" => assigned_by,
          "manager_assigned_at" => Time.current.iso8601,
          "manager_assignment_source" => "people_directory"
        )
      )
    end

    def generate_snapshot(requested_by:)
      roster = employees.to_a
      snapshot = {
        "snapshot_id" => "people_directory_#{@employer.id}_#{Time.current.to_i}",
        "generated_at" => Time.current.iso8601,
        "requested_by" => requested_by,
        "employer_id" => @employer.id,
        "status" => directory_issues(roster).empty? ? "ready" : "needs_review",
        "totals" => {
          "employee_count" => roster.count,
          "manager_count" => manager_nodes(roster).count,
          "assigned_count" => roster.count { |employee| employee.manager_id.present? },
          "unassigned_count" => unassigned_reports(roster).count,
          "issue_count" => directory_issues(roster).count
        },
        "managers" => manager_nodes(roster),
        "employees" => roster.map { |employee| snapshot_line(employee, roster) },
        "issues" => directory_issues(roster)
      }

      @employer.update!(settings: @employer.settings.to_h.merge(SNAPSHOT_KEY => snapshot))
      snapshot
    end

    private

    def manager_nodes(roster)
      roster
        .select { |employee| direct_report_count(employee, roster).positive? || department_manager_ids.include?(employee.id) }
        .map { |employee| snapshot_line(employee, roster) }
    end

    def unassigned_reports(roster)
      roster.reject do |employee|
        employee.manager_id.present? ||
          direct_report_count(employee, roster).positive? ||
          department_manager_ids.include?(employee.id)
      end
    end

    def directory_issues(roster)
      issues = []

      unassigned_reports(roster).each do |employee|
        issues << issue_line(employee, "missing_manager", "Employee has no manager assigned and is not a department manager.")
      end

      departments.each do |department|
        next if department.manager_id.present?

        issues << {
          "employee_id" => nil,
          "employee_name" => department.name,
          "department_name" => department.name,
          "status" => "needs_review",
          "reason_code" => "missing_department_manager",
          "reason" => "Department has no manager assigned."
        }
      end

      issues
    end

    def issue_line(employee, reason_code, reason)
      {
        "employee_id" => employee.id,
        "employee_name" => employee.full_name,
        "department_name" => employee.department&.name || "Unassigned",
        "status" => "needs_review",
        "reason_code" => reason_code,
        "reason" => reason
      }
    end

    def snapshot_line(employee, roster)
      {
        "employee_id" => employee.id,
        "employee_name" => employee.full_name,
        "title" => employee.title,
        "department_name" => employee.department&.name || "Unassigned",
        "location_name" => employee.work_location&.name || "Unassigned",
        "manager_id" => employee.manager_id,
        "manager_name" => employee.manager&.full_name,
        "direct_report_count" => direct_report_count(employee, roster),
        "remote_employee_id" => employee.vitable_id,
        "status" => employee.manager_id.present? || direct_report_count(employee, roster).positive? ? "ready" : "needs_review"
      }
    end

    def direct_report_count(employee, roster)
      roster.count { |candidate| candidate.manager_id == employee.id }
    end

    def department_manager_ids
      @department_manager_ids ||= departments.map(&:manager_id).compact
    end
  end
end
