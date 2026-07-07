module Benefits
  class PlanAdministrationRepository < ApplicationRepository
    PACKET_KEY = "benefit_plan_catalog_packet"
    REMOTE_SNAPSHOT_KEY = "vitable_plan_catalog_snapshot"
    PLAN_MAPPING_OPERATION = "plan_mapping_refresh"
    PLAN_MAPPING_REQUEST_OPERATION = "plan.list"

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

    def latest_remote_snapshot
      @employer&.settings.to_h.fetch(REMOTE_SNAPSHOT_KEY, nil)
    end

    def connection
      @connection ||= vitable_connection_for(@employer&.organization)
    end

    def mapping_runs(limit: 8)
      return SyncRun.none unless connection

      connection.sync_runs.where(operation: PLAN_MAPPING_OPERATION).recent_first.limit(limit)
    end

    def request_logs(limit: 8)
      return ApiRequestLog.none unless connection

      connection.api_request_logs.where(operation: PLAN_MAPPING_REQUEST_OPERATION).recent_first.limit(limit)
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
      issues << issue_line(plan, "medium", "missing_remote_plan_id", "Map this local plan to a Vitable plan before it can be used in member sync.") if plan.vitable_id.blank?
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

    def create_mapping_run(requested_by:)
      connection.sync_runs.create!(
        resource_type: "benefit_plan",
        operation: PLAN_MAPPING_OPERATION,
        status: "running",
        started_at: Time.current,
        stats: {
          "requested_by" => requested_by,
          "resource_id" => "employer_#{@employer.id}",
          "endpoint" => "/v1/plans"
        }
      )
    end

    def mark_mapping_needs_credentials(sync_run)
      message = "#{connection.api_key_reference} is not configured"
      sync_run.update!(
        status: "needs_credentials",
        completed_at: Time.current,
        error_message: message,
        stats: sync_run.stats.to_h.merge("blocked_reason" => message)
      )
      sync_run
    end

    def mark_mapping_succeeded(sync_run, response)
      response_hash = serialize_response(response)
      remote_plans = response_hash.fetch("data", []).map { |payload| payload.to_h.stringify_keys }
      mapping = reconcile_remote_plans(remote_plans)
      refreshed_at = Time.current.iso8601
      snapshot = mapping.merge(
        "refreshed_at" => refreshed_at,
        "remote_plans" => remote_plans
      )

      @employer.update!(settings: @employer.settings.to_h.merge(REMOTE_SNAPSHOT_KEY => snapshot))
      sync_run.update!(
        status: "succeeded",
        completed_at: Time.current,
        error_message: nil,
        stats: sync_run.stats.to_h.merge(
          "remote_response" => response_hash,
          "remote_plan_count" => remote_plans.count,
          "mapped_plan_count" => mapping.fetch("mapped_plan_count"),
          "unmatched_remote_count" => mapping.fetch("unmatched_remote_plans").count,
          "unmatched_local_count" => mapping.fetch("unmatched_local_plans").count,
          "refreshed_at" => refreshed_at
        )
      )
      sync_run
    end

    def mark_mapping_failed(sync_run, error)
      sync_run&.update!(
        status: "failed",
        completed_at: Time.current,
        error_message: error.message,
        stats: sync_run.stats.to_h.merge("error_class" => error.class.name)
      )
      sync_run
    end

    private

    def publish_blocking_issues(plan)
      readiness_issues(plan).reject { |issue| issue.reason_code.in?(%w[unpublished_plan missing_remote_plan_id]) }
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
        "remote_action" => plan.vitable_id.present? ? "mapped" : "needs_mapping",
        "status" => "ready"
      }
    end

    def reconcile_remote_plans(remote_plans)
      local_plans = plans.to_a
      mapped = []
      ambiguous = []
      unmatched_remote = []

      remote_plans.each do |remote_plan|
        candidates = local_matches_for(remote_plan, local_plans)
        if candidates.one?
          plan = candidates.first
          apply_remote_plan_mapping(plan, remote_plan)
          mapped << mapping_line(plan, remote_plan)
        elsif candidates.many?
          ambiguous << {
            "remote_plan_id" => remote_plan.fetch("id", nil),
            "remote_plan_name" => remote_plan.fetch("name", nil),
            "candidate_plan_ids" => candidates.map(&:id),
            "candidate_plan_names" => candidates.map(&:name)
          }
        else
          unmatched_remote << remote_plan.slice("id", "name")
        end
      end

      mapped_local_ids = mapped.map { |entry| entry.fetch("local_plan_id") }
      unmatched_local = local_plans.reject { |plan| mapped_local_ids.include?(plan.id) || plan.vitable_id.present? }.map do |plan|
        {
          "local_plan_id" => plan.id,
          "local_plan_name" => plan.name,
          "category" => plan.category
        }
      end

      {
        "mapped_plan_count" => mapped.count,
        "mapped_plans" => mapped,
        "ambiguous_remote_plans" => ambiguous,
        "unmatched_remote_plans" => unmatched_remote,
        "unmatched_local_plans" => unmatched_local
      }
    end

    def local_matches_for(remote_plan, local_plans)
      remote_name = remote_plan.fetch("name", "").to_s
      normalized_remote = normalize_plan_name(remote_name)
      exact = local_plans.select { |plan| normalize_plan_name(plan.name) == normalized_remote }
      return exact if exact.any?

      contained = local_plans.select do |plan|
        normalized_local = normalize_plan_name(plan.name)
        normalized_local.include?(normalized_remote) || normalized_remote.include?(normalized_local)
      end
      return contained if contained.one?

      category = category_for_remote_plan(remote_name)
      category ? local_plans.select { |plan| plan.category == category } : []
    end

    def apply_remote_plan_mapping(plan, remote_plan)
      mapped_at = Time.current.iso8601
      plan.update!(
        vitable_id: remote_plan.fetch("id"),
        metadata: plan.metadata.to_h.merge(
          "vitable_plan_mapping" => {
            "remote_plan_id" => remote_plan.fetch("id"),
            "remote_plan_name" => remote_plan.fetch("name"),
            "matched_at" => mapped_at,
            "matched_by" => "plans.list"
          }
        )
      )
    end

    def mapping_line(plan, remote_plan)
      {
        "local_plan_id" => plan.id,
        "local_plan_name" => plan.name,
        "remote_plan_id" => remote_plan.fetch("id"),
        "remote_plan_name" => remote_plan.fetch("name"),
        "category" => plan.category
      }
    end

    def normalize_plan_name(value)
      value.to_s.downcase.gsub(/[^a-z0-9]+/, "")
    end

    def category_for_remote_plan(name)
      normalized = name.to_s.downcase
      return "direct_primary_care" if normalized.match?(/direct primary care|primary care|\bdpc\b/)
      return "minimum_essential_coverage" if normalized.match?(/minimum essential|mec/)
      return "dental_vision" if normalized.match?(/dental.*vision|vision.*dental/)
      return "dental" if normalized.include?("dental")
      return "vision" if normalized.include?("vision")

      nil
    end

    def serialize_response(response)
      return {} if response.blank?
      return response.deep_to_h.deep_stringify_keys if response.respond_to?(:deep_to_h)
      return response.to_h.deep_stringify_keys if response.respond_to?(:to_h)

      { "value" => response.to_s }
    end
  end
end
