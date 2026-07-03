module Benefits
  class PlanAdministrationRepository < ApplicationRepository
    PACKET_KEY = "benefit_plan_catalog_packet"

    def initialize(employer:)
      @employer = employer
    end

    def plans
      return BenefitPlan.none unless @employer

      @employer.benefit_plans.includes(:enrollments).order(:plan_year, :category, :name)
    end

    def find_plan(id)
      plans.find(id)
    end

    def latest_packet
      @employer&.settings.to_h.fetch(PACKET_KEY, nil)
    end

    def publish_plan(plan, published_by:)
      return false if publish_blocking_issues(plan).any?

      plan.update!(
        status: "available",
        review_status: "published",
        published_at: Time.current,
        metadata: plan.metadata.to_h.merge(
          "published_by" => published_by,
          "published_from" => "benefit_plan_administration",
          "published_at" => Time.current.iso8601
        )
      )
    end

    def readiness_issues(plan)
      issues = []
      issues << issue_line(plan, "high", "missing_carrier", "Carrier must be set before the plan catalog can be synchronized.") if plan.carrier.blank?
      issues << issue_line(plan, "high", "missing_plan_year", "Plan year is required for enrollment and billing period mapping.") if plan.plan_year.blank?
      issues << issue_line(plan, "high", "missing_effective_window", "Effective and expiration dates are required for employee eligibility windows.") if plan.effective_on.blank? || plan.expires_on.blank?
      issues << issue_line(plan, "high", "invalid_effective_window", "Expiration date must be after the effective date.") if plan.effective_on.present? && plan.expires_on.present? && plan.expires_on <= plan.effective_on
      issues << issue_line(plan, "high", "contribution_mismatch", "Employee and employer contributions must equal the monthly premium.") if contribution_balance_cents(plan) != 0
      issues << issue_line(plan, "medium", "unpublished_plan", "Plan is not published for open enrollment or Vitable catalog sync.") unless plan.review_status == "published"
      issues << issue_line(plan, "medium", "inactive_plan", "Plan status should be available before employees can enroll.") unless plan.status == "available"
      issues
    end

    def generate_catalog_packet(requested_by:)
      roster = plans.to_a
      ready_plans, holdback_plans = roster.partition { |plan| readiness_issues(plan).empty? }
      packet = {
        "packet_id" => "benefit_plan_catalog_#{@employer.id}_#{Time.current.to_i}",
        "generated_at" => Time.current.iso8601,
        "requested_by" => requested_by,
        "employer_id" => @employer.id,
        "status" => holdback_plans.empty? ? "ready" : "needs_review",
        "totals" => {
          "plan_count" => roster.count,
          "ready_count" => ready_plans.count,
          "holdback_count" => holdback_plans.count,
          "monthly_premium_cents" => ready_plans.sum(&:monthly_premium_cents),
          "employee_contribution_cents" => ready_plans.sum(&:employee_contribution_cents),
          "employer_contribution_cents" => ready_plans.sum(&:employer_contribution_cents)
        },
        "plans" => ready_plans.map { |plan| plan_line(plan) },
        "holdbacks" => holdback_plans.flat_map { |plan| readiness_issues(plan).map { |issue| issue.to_h.stringify_keys } }
      }

      @employer.update!(settings: @employer.settings.to_h.merge(PACKET_KEY => packet))
      packet
    end

    private

    def publish_blocking_issues(plan)
      readiness_issues(plan).reject { |issue| issue.reason_code == "unpublished_plan" }
    end

    def contribution_balance_cents(plan)
      plan.monthly_premium_cents - plan.employee_contribution_cents - plan.employer_contribution_cents
    end

    def issue_line(plan, severity, reason_code, reason)
      PlanReadinessIssueDto.new(plan_id: plan.id, plan_name: plan.name, severity:, status: "needs_review", reason_code:, reason:)
    end

    def plan_line(plan)
      {
        "plan_id" => plan.id,
        "plan_name" => plan.name,
        "category" => plan.category,
        "carrier" => plan.carrier,
        "plan_year" => plan.plan_year,
        "effective_on" => plan.effective_on&.iso8601,
        "expires_on" => plan.expires_on&.iso8601,
        "monthly_premium_cents" => plan.monthly_premium_cents,
        "employee_contribution_cents" => plan.employee_contribution_cents,
        "employer_contribution_cents" => plan.employer_contribution_cents,
        "contribution_strategy" => plan.contribution_strategy,
        "eligibility_rule" => plan.eligibility_rule,
        "remote_plan_id" => plan.vitable_id,
        "remote_action" => plan.vitable_id.present? ? "update" : "create",
        "status" => "ready"
      }
    end
  end
end
