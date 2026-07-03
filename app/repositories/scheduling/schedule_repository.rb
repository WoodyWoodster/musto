module Scheduling
  class ScheduleRepository < ApplicationRepository
    def initialize(employer: nil)
      @employer = employer
    end

    def shifts
      return WorkShift.none unless @employer

      @employer
        .work_shifts
        .current_window
        .includes(:department, :work_location, employee: [ :department, :work_location ])
        .chronological
    end

    def swap_requests
      return ShiftSwapRequest.none unless @employer

      ShiftSwapRequest
        .joins(:work_shift)
        .where(work_shifts: { employer_id: @employer.id })
        .includes(:requester, :target_employee, work_shift: [ :department, :work_location ])
        .current_first
    end

    def current_run
      return unless @employer

      @employer.payroll_runs.order(pay_date: :desc).first
    end

    def forecasts
      payload = @employer&.settings.to_h.fetch("schedule_payroll_forecast", nil)
      payload.present? ? [ payload ] : []
    end

    def find_swap(id)
      scope = ShiftSwapRequest.includes(:requester, :target_employee, work_shift: [ :employer, :employee, :department, :work_location ])
      scope = scope.joins(:work_shift).where(work_shifts: { employer_id: @employer.id }) if @employer
      scope.find(id)
    end

    def publish_schedule(published_by:)
      published = []

      WorkShift.transaction do
        shifts.where(status: "draft").to_a.each do |shift|
          shift.publish!(published_by:)
          published << shift
        end
      end

      published
    end

    def approve_swap(swap, reviewed_by:)
      return false unless swap.reviewable?

      swap.approve!(reviewed_by:)
    end

    def generate_forecast(requested_by:)
      run = current_run
      return empty_forecast(requested_by:) unless run

      forecast_shifts = shifts_for_run(run)
      lines, holdbacks = forecast_lines(forecast_shifts)
      forecast = forecast_payload(run, lines, holdbacks, requested_by:)

      @employer.update!(settings: @employer.settings.to_h.merge("schedule_payroll_forecast" => forecast))
      forecast
    end

    private

    def shifts_for_run(run)
      @employer
        .work_shifts
        .where(starts_at: run.period_start_on.beginning_of_day..run.period_end_on.end_of_day)
        .includes(:department, :work_location, :employee)
        .chronological
    end

    def forecast_lines(records)
      lines = []
      holdbacks = []

      records.each do |shift|
        if shift.payable?
          lines << line_payload(shift)
        else
          holdbacks << holdback_payload(shift)
        end
      end

      holdbacks << empty_holdback("No published payable shifts are available for forecast") if lines.empty?
      [ lines, holdbacks ]
    end

    def forecast_payload(run, lines, holdbacks, requested_by:)
      {
        "batch_id" => "schedule_forecast_#{@employer.id}_#{run.id}_#{Time.current.to_i}",
        "generated_at" => Time.current.iso8601,
        "requested_by" => requested_by,
        "payroll_run_id" => run.id,
        "employer_id" => @employer.id,
        "period_start_on" => run.period_start_on.iso8601,
        "period_end_on" => run.period_end_on.iso8601,
        "status" => lines.any? && holdbacks.empty? ? "ready" : "needs_review",
        "totals" => {
          "line_count" => lines.count,
          "employee_count" => lines.map { |line| line.fetch("employee_id") }.uniq.count,
          "holdback_count" => holdbacks.count,
          "total_minutes" => lines.sum { |line| line.fetch("net_minutes") },
          "total_labor_cents" => lines.sum { |line| line.fetch("labor_cost_cents") }
        },
        "lines" => lines,
        "holdbacks" => holdbacks
      }
    end

    def empty_forecast(requested_by:)
      {
        "batch_id" => "schedule_forecast_#{@employer.id}_missing_run_#{Time.current.to_i}",
        "generated_at" => Time.current.iso8601,
        "requested_by" => requested_by,
        "payroll_run_id" => nil,
        "employer_id" => @employer.id,
        "period_start_on" => Date.current.iso8601,
        "period_end_on" => Date.current.iso8601,
        "status" => "needs_review",
        "totals" => { "line_count" => 0, "employee_count" => 0, "holdback_count" => 1, "total_minutes" => 0, "total_labor_cents" => 0 },
        "lines" => [],
        "holdbacks" => [ empty_holdback("No current payroll run is available for schedule forecast") ]
      }
    end

    def line_payload(shift)
      {
        "shift_id" => shift.id,
        "employee_id" => shift.employee_id,
        "employee_name" => shift.employee.full_name,
        "role" => shift.role,
        "department_name" => shift.department&.name,
        "location_name" => shift.work_location&.name,
        "starts_at" => shift.starts_at.iso8601,
        "ends_at" => shift.ends_at.iso8601,
        "net_minutes" => shift.net_minutes,
        "hourly_rate_cents" => shift.hourly_rate_cents,
        "labor_cost_cents" => shift.labor_cost_cents,
        "status" => "forecast_ready"
      }
    end

    def holdback_payload(shift)
      {
        "shift_id" => shift.id,
        "employee_name" => shift.employee&.full_name || "Open shift",
        "role" => shift.role,
        "starts_at" => shift.starts_at.iso8601,
        "status" => holdback_status(shift),
        "reason" => holdback_reason(shift)
      }
    end

    def empty_holdback(reason)
      {
        "shift_id" => nil,
        "employee_name" => "Schedule",
        "role" => "Payroll forecast",
        "starts_at" => Date.current.iso8601,
        "status" => "needs_review",
        "reason" => reason
      }
    end

    def holdback_status(shift)
      return "coverage_gap" if shift.open_shift?
      return "draft" if shift.draft?
      return shift.status if shift.canceled? || shift.missed?

      "needs_review"
    end

    def holdback_reason(shift)
      return "Shift is unassigned" if shift.open_shift?
      return "Shift must be published before payroll forecast" if shift.draft?
      return "Shift is canceled" if shift.canceled?
      return "Missed shift needs manager review" if shift.missed?
      return "Hourly rate is missing" unless shift.hourly_rate_cents.positive?

      "Shift is not ready for payroll forecast"
    end
  end
end
