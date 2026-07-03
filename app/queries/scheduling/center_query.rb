module Scheduling
  class CenterQuery
    def initialize(employer_repository: Employers::EmployerRepository.new)
      @employer = employer_repository.first_for_operations
      @repository = ScheduleRepository.new(employer: @employer)
    end

    def call
      shifts = @repository.shifts.to_a
      swaps = @repository.swap_requests.to_a
      forecasts = @repository.forecasts
      latest_forecast = forecasts.first.to_h

      CenterDto.new(
        employer: Operations::EmployerContextDto.from_record(@employer),
        metrics: metrics(shifts, swaps),
        shifts: shifts.map { |shift| ShiftDto.from_record(shift) },
        swap_requests: swaps.map { |swap| SwapRequestDto.from_record(swap) },
        issues: issues(shifts, swaps),
        forecasts: forecasts.map { |payload| ForecastDto.from_hash(payload) },
        forecast_lines: latest_forecast.fetch("lines", []).map { |payload| ForecastLineDto.from_hash(payload) },
        forecast_holdbacks: latest_forecast.fetch("holdbacks", []).map { |payload| ForecastHoldbackDto.from_hash(payload) },
        forecast_payload: forecasts.first
      )
    end

    private

    def metrics(shifts, swaps)
      published = shifts.count(&:published?)
      draft = shifts.count(&:draft?)
      open = shifts.count(&:open_shift?)
      labor_cost = shifts.select(&:payable?).sum(&:labor_cost_cents)

      [
        MetricDto.new(label: "Published shifts", value: published, hint: "#{draft} draft shifts waiting", status: published.positive? ? "published" : "needs_review", accent: "bg-teal-500", format: "number"),
        MetricDto.new(label: "Forecast labor", value: labor_cost, hint: "scheduled payable labor", status: labor_cost.positive? ? "forecast_ready" : "pending", accent: "bg-indigo-500", format: "money"),
        MetricDto.new(label: "Coverage gaps", value: open, hint: "open shifts need owners", status: open.positive? ? "coverage_gap" : "ready", accent: "bg-rose-500", format: "number"),
        MetricDto.new(label: "Swap queue", value: swaps.count(&:reviewable?), hint: "#{swaps.count} swap requests tracked", status: swaps.any?(&:reviewable?) ? "submitted" : "ready", accent: "bg-amber-500", format: "number")
      ]
    end

    def issues(shifts, swaps)
      routes = Rails.application.routes.url_helpers
      items = []
      drafts = shifts.select(&:draft?)
      open = shifts.select(&:open_shift?)
      missed = shifts.select(&:missed?)
      reviewable_swaps = swaps.select(&:reviewable?)
      payable = shifts.select(&:payable?)

      if drafts.any?
        items << IssueDto.new(key: "publish_schedule", title: "Publish draft schedule", detail: "#{pluralized_count(drafts.count, "draft shift")} #{be_verb(drafts.count)} ready to publish for employees.", severity: "medium", status: "needs_review", owner: "Managers", count: drafts.count, amount_cents: drafts.sum(&:labor_cost_cents), action_path: routes.scheduling_path)
      end

      if open.any?
        items << IssueDto.new(key: "coverage_gaps", title: "Assign open shifts", detail: "#{pluralized_count(open.count, "open shift")} #{need_verb(open.count)} employee coverage before the schedule can be trusted.", severity: "high", status: "coverage_gap", owner: "Managers", count: open.count, amount_cents: open.sum(&:labor_cost_cents), action_path: routes.scheduling_path)
      end

      if reviewable_swaps.any?
        items << IssueDto.new(key: "swap_queue", title: "Review shift swaps", detail: "#{pluralized_count(reviewable_swaps.count, "swap request")} #{be_verb(reviewable_swaps.count)} waiting on manager approval.", severity: "medium", status: "submitted", owner: "Managers", count: reviewable_swaps.count, amount_cents: 0, action_path: routes.scheduling_path)
      end

      if missed.any?
        items << IssueDto.new(key: "missed_shifts", title: "Resolve missed shifts", detail: "#{pluralized_count(missed.count, "missed shift")} need payroll review before forecast export.", severity: "high", status: "missed", owner: "Payroll", count: missed.count, amount_cents: missed.sum(&:labor_cost_cents), action_path: routes.timesheets_path)
      end

      if payable.any?
        items << IssueDto.new(key: "forecast_ready", title: "Generate payroll forecast", detail: "#{pluralized_count(payable.count, "published shift")} #{be_verb(payable.count)} ready for payroll labor forecast.", severity: "low", status: "forecast_ready", owner: "Payroll", count: payable.count, amount_cents: payable.sum(&:labor_cost_cents), action_path: routes.scheduling_path)
      end

      return items if items.any?

      [
        IssueDto.new(key: "schedule_ready", title: "Schedule is ready", detail: "Coverage, swaps, and payroll forecast checks have no blockers.", severity: "low", status: "ready", owner: "Managers", count: shifts.count, amount_cents: 0, action_path: routes.scheduling_path)
      ]
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
  end
end
