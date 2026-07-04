module WorkersComp
  class CoverageRepository < ApplicationRepository
    PACKET_KEY = "workers_comp_audit_packet"
    DEFAULT_CLASS_CODE = "8810"
    CLASS_CODE_RULES = {
      "8810" => { "description" => "Clerical office employees", "rate_basis_points" => 32 },
      "8742" => { "description" => "Outside sales and customer success", "rate_basis_points" => 48 },
      "8803" => { "description" => "Payroll and accounting operations", "rate_basis_points" => 36 },
      "9079" => { "description" => "Office support and customer service", "rate_basis_points" => 215 }
    }.freeze

    def initialize(employer: nil)
      @employer = employer
    end

    def policies
      return WorkersCompPolicy.none unless @employer

      @employer.workers_comp_policies.includes(:workers_comp_claims).current_first
    end

    def current_policy
      policies.to_a.find(&:coverage_active?) || policies.first
    end

    def claims
      return WorkersCompClaim.none unless @employer

      @employer.workers_comp_claims.includes(:employee, :workers_comp_policy).recent_first
    end

    def employees
      return Employee.none unless @employer

      @employer.employees.includes(:department, :work_location).active.order(:last_name, :first_name)
    end

    def latest_packet
      @employer&.settings.to_h.fetch(PACKET_KEY, nil)
    end

    def exposures
      employees.to_a
        .group_by { |employee| [ class_code_for(employee), service_state_for(employee), class_description_for(class_code_for(employee)), rate_basis_points_for(employee) ] }
        .map do |(class_code, state, description, rate_basis_points), grouped_employees|
          payroll_cents = grouped_employees.sum(&:compensation_cents)
          {
            "class_code" => class_code,
            "class_description" => description,
            "service_state" => state,
            "employee_count" => grouped_employees.count,
            "employee_names" => grouped_employees.map(&:full_name),
            "payroll_cents" => payroll_cents,
            "rate_basis_points" => rate_basis_points,
            "estimated_premium_cents" => premium_for(payroll_cents, rate_basis_points)
          }
        end
        .sort_by { |line| [ line.fetch("service_state"), line.fetch("class_code") ] }
    end

    def issues
      issue_records = []
      policy = current_policy

      if policy.blank?
        issue_records << issue("missing_policy", "critical", "blocked", "Workers' comp policy is missing.", nil)
      else
        issue_records << issue("policy_expired", "critical", "blocked", "Policy coverage has expired.", policy.id) if policy.expired?
        issue_records << issue("renewal_due", "medium", "needs_review", "Policy renewal is due by #{policy.renewal_due_on.strftime("%b %-d, %Y")}.", policy.id) if policy.renewal_due?
        issue_records << issue("certificate_missing", "medium", "needs_review", "Certificate of insurance URL is missing.", policy.id) if policy.certificate_url.blank?
      end

      inferred_employees = employees.to_a.select { |employee| employee.metadata.to_h.fetch("workers_comp_class_code", nil).blank? }
      issue_records << issue("inferred_class_codes", "medium", "needs_review", "#{inferred_employees.count} employees are using inferred workers' comp class codes.", nil) if inferred_employees.any?

      open_lost_time = claims.open.lost_time.to_a
      issue_records << issue("open_lost_time_claims", "high", "needs_review", "#{open_lost_time.count} lost-time claims remain open.", nil) if open_lost_time.any?

      unnumbered_claims = claims.open.select { |claim| claim.claim_number.blank? }
      issue_records << issue("missing_claim_numbers", "medium", "needs_review", "#{unnumbered_claims.count} open claims are missing carrier claim numbers.", nil) if unnumbered_claims.any?

      issue_records
    end

    def find_claim(id)
      scope = WorkersCompClaim.includes(:employee, :workers_comp_policy)
      scope = scope.where(employer_id: @employer.id) if @employer
      scope.find(id)
    end

    def close_claim(claim, closed_by:, resolution:)
      return false unless claim.closable?

      claim.close!(closed_by:, resolution:)
    end

    def generate_audit_packet(requested_by:)
      policy = current_policy
      exposure_lines = exposures
      issue_records = issues
      claim_lines = claims.to_a.map { |claim| claim_line(claim) }
      packet = {
        "packet_id" => "workers_comp_audit_#{@employer.id}_#{policy&.id || "missing"}_#{Time.current.to_i}",
        "generated_at" => Time.current.iso8601,
        "requested_by" => requested_by,
        "employer_id" => @employer.id,
        "policy_id" => policy&.id,
        "policy_number" => policy&.policy_number,
        "status" => packet_status(issue_records),
        "coverage_start_on" => policy&.coverage_start_on&.iso8601,
        "coverage_end_on" => policy&.coverage_end_on&.iso8601,
        "totals" => {
          "exposure_count" => exposure_lines.count,
          "employee_count" => exposure_lines.sum { |line| line.fetch("employee_count") },
          "payroll_basis_cents" => exposure_lines.sum { |line| line.fetch("payroll_cents") },
          "estimated_premium_cents" => exposure_lines.sum { |line| line.fetch("estimated_premium_cents") },
          "claim_count" => claim_lines.count,
          "open_claim_count" => claim_lines.count { |claim| claim.fetch("status").in?(%w[reported investigating accepted]) },
          "reserve_cents" => claim_lines.sum { |claim| claim.fetch("reserve_cents") },
          "holdback_count" => issue_records.count
        },
        "lines" => exposure_lines,
        "claims" => claim_lines,
        "holdbacks" => issue_records
      }

      @employer.update!(settings: @employer.settings.to_h.merge(PACKET_KEY => packet))
      packet
    end

    def class_code_for(employee)
      employee.metadata.to_h.fetch("workers_comp_class_code", nil).presence || inferred_class_code_for(employee)
    end

    def service_state_for(employee)
      employee.metadata.to_h.fetch("workers_comp_state", nil).presence || employee.work_location&.state.presence || "Remote"
    end

    def rate_basis_points_for(employee)
      employee.metadata.to_h.fetch("workers_comp_rate_basis_points", nil).presence&.to_i || CLASS_CODE_RULES.fetch(class_code_for(employee), CLASS_CODE_RULES.fetch(DEFAULT_CLASS_CODE)).fetch("rate_basis_points")
    end

    private

    def inferred_class_code_for(employee)
      case employee.department&.code
      when "RET"
        "9079"
      when "FIN"
        "8803"
      when "SLS"
        "8742"
      else
        DEFAULT_CLASS_CODE
      end
    end

    def class_description_for(class_code)
      CLASS_CODE_RULES.fetch(class_code, CLASS_CODE_RULES.fetch(DEFAULT_CLASS_CODE)).fetch("description")
    end

    def premium_for(payroll_cents, rate_basis_points)
      ((payroll_cents.to_i * rate_basis_points.to_i) / 10_000.0).round
    end

    def claim_line(claim)
      {
        "claim_id" => claim.id,
        "employee_id" => claim.employee_id,
        "employee_name" => claim.employee.full_name,
        "claim_number" => claim.claim_number,
        "incident_on" => claim.incident_on.iso8601,
        "reported_on" => claim.reported_on.iso8601,
        "status" => claim.status,
        "severity" => claim.severity,
        "injury_type" => claim.injury_type,
        "body_part" => claim.body_part,
        "lost_time_days" => claim.lost_time_days,
        "reserve_cents" => claim.reserve_cents,
        "paid_cents" => claim.paid_cents,
        "return_to_work_on" => claim.return_to_work_on&.iso8601
      }
    end

    def issue(reason_code, severity, status, reason, policy_id)
      {
        "reason_code" => reason_code,
        "severity" => severity,
        "status" => status,
        "reason" => reason,
        "policy_id" => policy_id
      }
    end

    def packet_status(issue_records)
      issue_records.any? { |record| record.fetch("severity").in?(%w[critical high]) } ? "needs_review" : "ready"
    end
  end
end
