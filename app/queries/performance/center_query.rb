module Performance
  class CenterQuery
    def initialize(employer_repository: Employers::EmployerRepository.new)
      @employer = employer_repository.first_for_operations
      @repository = PerformanceRepository.new(employer: @employer)
    end

    def call
      cycles = @repository.cycles.to_a
      reviews = @repository.reviews.to_a
      goals = @repository.goals.to_a
      batches = @repository.batches
      latest_batch = batches.first.to_h

      CenterDto.new(
        employer: Operations::EmployerContextDto.from_record(@employer),
        metrics: metrics(cycles, reviews, goals),
        cycles: cycles.map { |cycle| CycleDto.from_record(cycle) },
        reviews: reviews.map { |review| ReviewDto.from_record(review) },
        goals: goals.map { |goal| GoalDto.from_record(goal) },
        issues: issues(cycles, reviews, goals),
        calibration_batches: batches.map { |payload| CalibrationBatchDto.from_hash(payload) },
        calibration_lines: latest_batch.fetch("reviews", []).map { |payload| CalibrationLineDto.from_hash(payload) },
        calibration_holdbacks: latest_batch.fetch("holdbacks", []).map { |payload| CalibrationHoldbackDto.from_hash(payload) },
        calibration_payload: batches.first
      )
    end

    private

    def metrics(cycles, reviews, goals)
      active_cycles = cycles.count(&:active?)
      open_reviews = reviews.count { |review| !review.complete? }
      calibratable = reviews.count(&:calibratable?)
      at_risk_goals = goals.count(&:at_risk?)

      [
        MetricDto.new(label: "Active cycles", value: active_cycles, hint: "#{cycles.count} total review cycles", status: active_cycles.positive? ? "active" : "needs_review", accent: "bg-indigo-500", format: "number"),
        MetricDto.new(label: "Open reviews", value: open_reviews, hint: "#{reviews.count} review records", status: open_reviews.positive? ? "in_progress" : "ready", accent: "bg-cyan-500", format: "number"),
        MetricDto.new(label: "Calibration ready", value: calibratable, hint: "manager reviews ready", status: calibratable.positive? ? "ready" : "pending", accent: "bg-emerald-500", format: "number"),
        MetricDto.new(label: "At-risk goals", value: at_risk_goals, hint: "need manager attention", status: at_risk_goals.positive? ? "blocked" : "on_track", accent: "bg-rose-500", format: "number")
      ]
    end

    def issues(cycles, reviews, goals)
      routes = Rails.application.routes.url_helpers
      items = []
      draft_cycles = cycles.select(&:draft?)
      overdue_reviews = reviews.select(&:overdue?)
      manager_reviews = reviews.select(&:calibratable?)
      at_risk_goals = goals.select(&:at_risk?)
      missing_reviewers = reviews.select { |review| review.reviewer_id.blank? && !review.complete? }

      if draft_cycles.any?
        items << IssueDto.new(key: "launch_cycle", title: "Launch review cycle", detail: "#{pluralized_count(draft_cycles.count, "draft cycle")} #{be_verb(draft_cycles.count)} ready to create employee review assignments.", severity: "medium", status: "needs_review", owner: "People Ops", count: draft_cycles.count, action_path: routes.performance_path)
      end

      if manager_reviews.any?
        items << IssueDto.new(key: "calibration_ready", title: "Generate calibration packet", detail: "#{pluralized_count(manager_reviews.count, "manager review")} #{be_verb(manager_reviews.count)} ready for calibration.", severity: "medium", status: "ready", owner: "People Ops", count: manager_reviews.count, action_path: routes.performance_path)
      end

      if overdue_reviews.any?
        items << IssueDto.new(key: "overdue_reviews", title: "Follow up on overdue reviews", detail: "#{pluralized_count(overdue_reviews.count, "review")} #{be_verb(overdue_reviews.count)} past due.", severity: "high", status: "overdue", owner: "Managers", count: overdue_reviews.count, action_path: routes.performance_path)
      end

      if at_risk_goals.any?
        items << IssueDto.new(key: "at_risk_goals", title: "Unblock at-risk goals", detail: "#{pluralized_count(at_risk_goals.count, "goal")} need manager attention before the next review cycle closes.", severity: "medium", status: "blocked", owner: "Managers", count: at_risk_goals.count, action_path: routes.performance_path)
      end

      if missing_reviewers.any?
        items << IssueDto.new(key: "missing_reviewers", title: "Assign missing reviewers", detail: "#{pluralized_count(missing_reviewers.count, "review")} need a manager reviewer.", severity: "medium", status: "needs_review", owner: "People Ops", count: missing_reviewers.count, action_path: routes.workforce_path)
      end

      return items if items.any?

      [
        IssueDto.new(key: "performance_ready", title: "Performance program is on track", detail: "Review cycles, goals, and calibration packets are moving without blockers.", severity: "low", status: "ready", owner: "People Ops", count: reviews.count, action_path: routes.performance_path)
      ]
    end

    def pluralized_count(count, noun)
      "#{count} #{noun.pluralize(count)}"
    end

    def be_verb(count)
      count == 1 ? "is" : "are"
    end
  end
end
