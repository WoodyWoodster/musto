module TimeTracking
  class TimeTrackingRepository < ApplicationRepository
    HOURLY_RATE_CENTS = 3_250

    def initialize(employer: nil)
      @employer = employer
    end

    def employees
      return Employee.none unless @employer

      @employer.employees.active.includes(:department, :work_location, :time_entries).order(:last_name, :first_name)
    end

    def departments
      return Department.none unless @employer

      @employer.departments.includes(employees: [ :time_entries ]).order(:name)
    end

    def entries
      return TimeEntry.none unless @employer

      TimeEntry
        .joins(:employee)
        .where(employees: { employer_id: @employer.id })
        .includes(employee: [ :department, :work_location ])
        .order(work_date: :desc, clock_in_at: :desc)
    end

    def current_payroll_run
      return unless @employer

      @employer.payroll_runs.order(pay_date: :desc).first
    end

    def find_entry(id)
      TimeEntry.includes(employee: [ :department, :work_location ]).find(id)
    end

    def review_entry(entry, decision:, reviewed_by:)
      entry.review!(decision:, reviewed_by:)
      entry
    end

    def exports
      payload = @employer&.settings.to_h.fetch("time_tracking_export", nil)
      payload.present? ? [ payload ] : []
    end

    def generate_payroll_export(requested_by:)
      run = current_payroll_run
      period_entries = exportable_entries(run)
      approved_entries = period_entries.select(&:approved?)
      holdbacks = period_entries.reject(&:approved?)
      lines = export_lines(approved_entries)
      export = {
        "export_id" => "time_export_#{@employer.id}_#{Time.current.to_i}",
        "generated_at" => Time.current.iso8601,
        "requested_by" => requested_by,
        "employer_id" => @employer.id,
        "payroll_run_id" => run&.id,
        "status" => holdbacks.any? ? "needs_review" : "ready",
        "totals" => {
          "line_count" => lines.count,
          "approved_minutes" => approved_entries.sum(&:duration_minutes),
          "holdback_count" => holdbacks.count,
          "total_gross_cents" => lines.sum { |line| line.fetch("gross_pay_cents") }
        },
        "lines" => lines,
        "holdbacks" => holdbacks.map { |entry| holdback_line(entry) }
      }

      @employer.update!(settings: @employer.settings.to_h.merge("time_tracking_export" => export))
      export
    end

    private

    def exportable_entries(run)
      return entries.to_a unless run

      entries.for_period(run.period_start_on, run.period_end_on).to_a
    end

    def export_lines(entries)
      entries.group_by(&:employee).map do |employee, employee_entries|
        regular_minutes = [ employee_entries.sum(&:duration_minutes), 2_400 ].min
        overtime_minutes = [ employee_entries.sum(&:duration_minutes) - 2_400, 0 ].max
        {
          "employee_id" => employee.id,
          "employee_name" => employee.full_name,
          "regular_minutes" => regular_minutes,
          "overtime_minutes" => overtime_minutes,
          "gross_pay_cents" => gross_pay_cents(regular_minutes, overtime_minutes),
          "entry_ids" => employee_entries.map(&:id)
        }
      end
    end

    def gross_pay_cents(regular_minutes, overtime_minutes)
      regular_hours = regular_minutes / 60.0
      overtime_hours = overtime_minutes / 60.0

      ((regular_hours * HOURLY_RATE_CENTS) + (overtime_hours * HOURLY_RATE_CENTS * 1.5)).round
    end

    def holdback_line(entry)
      {
        "entry_id" => entry.id,
        "employee_id" => entry.employee_id,
        "employee_name" => entry.employee.full_name,
        "work_date" => entry.work_date.iso8601,
        "status" => entry.status,
        "payable_minutes" => entry.duration_minutes
      }
    end
  end
end
