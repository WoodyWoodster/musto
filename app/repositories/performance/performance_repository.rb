module Performance
  class PerformanceRepository < ApplicationRepository
    def initialize(employer: nil)
      @employer = employer
    end

    def cycles
      return PerformanceCycle.none unless @employer

      @employer.performance_cycles.includes(:performance_reviews).current_first
    end

    def reviews
      return PerformanceReview.none unless @employer

      PerformanceReview
        .joins(:performance_cycle)
        .where(performance_cycles: { employer_id: @employer.id })
        .includes(:performance_cycle, :reviewer, employee: [ :department, :work_location ])
        .order(status: :asc, due_on: :asc, created_at: :desc)
    end

    def goals
      return EmployeeGoal.none unless @employer

      EmployeeGoal
        .joins(:employee)
        .where(employees: { employer_id: @employer.id })
        .includes(:performance_cycle, employee: [ :department, :work_location ])
        .order(status: :asc, due_on: :asc, created_at: :desc)
    end

    def batches
      payload = @employer&.settings.to_h.fetch("performance_calibration_packet", nil)
      payload.present? ? [ payload ] : []
    end

    def current_cycle
      cycles.where(status: %w[active calibration draft]).order(period_end_on: :desc).first || cycles.first
    end

    def find_review(id)
      scope = PerformanceReview.includes(:performance_cycle, :reviewer, employee: [ :employer, :department, :work_location ])
      scope = scope.joins(:performance_cycle).where(performance_cycles: { employer_id: @employer.id }) if @employer
      scope.find(id)
    end

    def find_goal(id)
      scope = EmployeeGoal.includes(:performance_cycle, employee: [ :employer, :department, :work_location ])
      scope = scope.joins(:employee).where(employees: { employer_id: @employer.id }) if @employer
      scope.find(id)
    end

    def launch_cycle(requested_by:)
      cycle = cycles.where(status: "draft").order(period_start_on: :desc).first || build_next_cycle
      employees = @employer.employees.active.includes(department: :manager).to_a

      PerformanceCycle.transaction do
        cycle.launch!(requested_by:) unless cycle.active?
        employees.each { |employee| ensure_review(cycle, employee) }
      end

      cycle
    end

    def calibrate_review(review, calibrated_by:)
      return false unless review.calibratable?

      review.update!(
        status: "complete",
        calibrated_at: Time.current,
        completed_at: Time.current,
        metadata: review.metadata.to_h.merge(
          "calibrated_by" => calibrated_by,
          "calibrated_at" => Time.current.iso8601
        )
      )
    end

    def complete_goal(goal, reviewed_by:)
      return false if goal.complete?

      goal.complete!(reviewed_by:)
    end

    def generate_calibration_packet(requested_by:)
      ready_reviews = reviews.calibratable.to_a
      holdback_reviews = reviews.where(status: %w[draft self_review overdue]).to_a
      lines = ready_reviews.map { |review| packet_line(review) }
      holdbacks = holdback_reviews.map { |review| holdback_line(review, reason: "Review is not ready for calibration") }
      holdbacks << empty_holdback("No manager reviews are ready for calibration") if lines.empty?
      batch = batch_payload(lines:, holdbacks:, requested_by:)

      PerformanceReview.transaction do
        @employer.update!(settings: @employer.settings.to_h.merge("performance_calibration_packet" => batch))
        ready_reviews.each { |review| review.update!(status: "calibration") unless review.calibration? }
        current_cycle&.update!(status: "calibration") if lines.any? && current_cycle&.active?
      end

      batch
    end

    private

    def build_next_cycle
      start_on = Date.current.beginning_of_quarter
      @employer.performance_cycles.create!(
        name: "Q#{((start_on.month - 1) / 3) + 1} #{start_on.year} Performance Review",
        review_type: "quarterly",
        period_start_on: start_on,
        period_end_on: start_on.end_of_quarter,
        due_on: start_on.end_of_quarter + 14.days,
        metadata: { "source" => "performance_center" }
      )
    end

    def ensure_review(cycle, employee)
      reviewer = employee.department&.manager
      reviewer = nil if reviewer == employee
      cycle.performance_reviews.find_or_initialize_by(employee:).tap do |review|
        review.assign_attributes(
          reviewer: reviewer || @employer.employees.active.where.not(id: employee.id).first,
          status: review.status.presence || "self_review",
          due_on: cycle.due_on,
          metadata: review.metadata.to_h.merge(
            "source" => "performance_cycle_launch",
            "launched_at" => Time.current.iso8601
          )
        )
        review.save!
      end
    end

    def batch_payload(lines:, holdbacks:, requested_by:)
      ratings = lines.filter_map { |line| line.fetch("rating", nil) }
      {
        "batch_id" => "performance_calibration_#{@employer.id}_#{Time.current.to_i}",
        "generated_at" => Time.current.iso8601,
        "requested_by" => requested_by,
        "employer_id" => @employer.id,
        "status" => lines.any? && holdbacks.empty? ? "ready" : "needs_review",
        "totals" => {
          "review_count" => lines.count,
          "employee_count" => lines.map { |line| line.fetch("employee_id") }.uniq.count,
          "holdback_count" => holdbacks.count,
          "average_rating" => ratings.any? ? (ratings.sum.to_f / ratings.count).round(2) : 0
        },
        "reviews" => lines,
        "holdbacks" => holdbacks
      }
    end

    def packet_line(review)
      {
        "review_id" => review.id,
        "employee_id" => review.employee_id,
        "employee_name" => review.employee.full_name,
        "department_name" => review.employee.department&.name,
        "reviewer_name" => review.reviewer&.full_name || "Reviewer pending",
        "rating" => review.rating,
        "status" => "calibration",
        "due_on" => review.due_on.iso8601,
        "strengths" => review.strengths,
        "growth_areas" => review.growth_areas
      }
    end

    def holdback_line(review, reason:)
      {
        "review_id" => review.id,
        "employee_name" => review.employee.full_name,
        "status" => review.overdue? ? "overdue" : review.status,
        "reason" => reason
      }
    end

    def empty_holdback(reason)
      {
        "review_id" => nil,
        "employee_name" => "Performance cycle",
        "status" => "needs_review",
        "reason" => reason
      }
    end
  end
end
