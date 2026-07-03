module Benefits
  PlanDesignDto = Data.define(
    :id,
    :name,
    :category,
    :carrier,
    :status,
    :review_status,
    :plan_year,
    :effective_on,
    :expires_on,
    :monthly_premium_cents,
    :employee_contribution_cents,
    :employer_contribution_cents,
    :contribution_strategy,
    :eligibility_rule,
    :vitable_id,
    :accepted_enrollment_count,
    :pending_enrollment_count,
    :readiness_status,
    :readiness_issues,
    :published_at
  ) do
    def self.from_record(record, readiness_issues:)
      enrollments = record.enrollments

      new(
        id: record.id,
        name: record.name,
        category: record.category,
        carrier: record.carrier,
        status: record.status,
        review_status: record.review_status,
        plan_year: record.plan_year,
        effective_on: record.effective_on,
        expires_on: record.expires_on,
        monthly_premium_cents: record.monthly_premium_cents,
        employee_contribution_cents: record.employee_contribution_cents,
        employer_contribution_cents: record.employer_contribution_cents,
        contribution_strategy: record.contribution_strategy,
        eligibility_rule: record.eligibility_rule,
        vitable_id: record.vitable_id,
        accepted_enrollment_count: enrollments.count { |enrollment| enrollment.status == "accepted" },
        pending_enrollment_count: enrollments.count { |enrollment| enrollment.status == "pending" },
        readiness_status: readiness_issues.empty? ? "ready" : "needs_review",
        readiness_issues:,
        published_at: record.published_at
      )
    end

    def contribution_balance_cents
      monthly_premium_cents - employee_contribution_cents - employer_contribution_cents
    end

    def publishable?
      readiness_issues.none? { |issue| issue.reason_code != "unpublished_plan" }
    end
  end
end
