module Vitable
  class BenefitPlanSnapshotRepository < ApplicationRepository
    def find_for_remote_enrollment(employer:, dto:)
      return [ nil, nil ] unless employer && dto

      if dto.remote_plan_id.present?
        plan = employer.benefit_plans.find_by(vitable_id: dto.remote_plan_id)
        return [ plan, "remote_plan_id" ] if plan
      end

      plan = plan_by_benefit_name(employer, dto.benefit_name)
      return [ plan, "benefit_name" ] if plan

      [ nil, nil ]
    end

    def sync_from_remote_enrollment(enrollment:, dto:, source:, refreshed_at:, match_strategy: nil)
      plan = enrollment&.benefit_plan
      return BenefitPlanSnapshotSyncResultDto.empty unless plan
      return BenefitPlanSnapshotSyncResultDto.empty if dto.remote_plan_id.blank? && dto.benefit_snapshot.blank?

      result = BenefitPlanSnapshotSyncResultDto.empty
      conflicting_plan = conflicting_plan_for(plan, dto.remote_plan_id)
      return result.record_conflict(plan:, remote_plan_id: dto.remote_plan_id, conflicting_plan:) if conflicting_plan

      plan.assign_attributes(plan_attributes(plan, dto, source:, refreshed_at:, match_strategy:))
      if plan.has_changes_to_save?
        plan.save!
        result.record_updated(plan.id)
      else
        result.record_unchanged(plan.id)
      end
    end

    private

    def plan_by_benefit_name(employer, benefit_name)
      return if benefit_name.blank?

      matches = employer.benefit_plans.select { |plan| normalize(plan.name) == normalize(benefit_name) }
      matches.one? ? matches.first : nil
    end

    def conflicting_plan_for(plan, remote_plan_id)
      return if remote_plan_id.blank?

      plan.employer.benefit_plans.where(vitable_id: remote_plan_id).where.not(id: plan.id).first
    end

    def plan_attributes(plan, dto, source:, refreshed_at:, match_strategy:)
      metadata = plan.metadata.to_h.stringify_keys.merge(
        "vitable_plan_mapping" => plan_mapping(plan, dto, source:, refreshed_at:, match_strategy:)
      )
      metadata["vitable_remote_benefit"] = dto.benefit_snapshot if dto.benefit_snapshot.present?

      attributes = {
        metadata:
      }
      attributes[:vitable_id] = dto.remote_plan_id if dto.remote_plan_id.present? && plan.vitable_id != dto.remote_plan_id
      attributes[:carrier] = "Vitable" if plan.carrier.blank?
      attributes
    end

    def plan_mapping(plan, dto, source:, refreshed_at:, match_strategy:)
      existing = plan.metadata.to_h.stringify_keys.fetch("vitable_plan_mapping", {}).to_h.stringify_keys
      mapping = existing.merge(
        "remote_plan_id" => dto.remote_plan_id.presence || existing.fetch("remote_plan_id", nil),
        "remote_plan_name" => dto.benefit_name.presence || existing.fetch("remote_plan_name", nil),
        "remote_plan_snapshot" => dto.benefit_snapshot.presence || existing.fetch("remote_plan_snapshot", nil),
        "last_enrollment_matched_at" => refreshed_at,
        "last_enrollment_matched_by" => source,
        "last_enrollment_match_strategy" => match_strategy.presence || inferred_match_strategy(plan, dto)
      ).compact

      mapping["matched_at"] ||= refreshed_at
      mapping["matched_by"] ||= source
      mapping["match_strategy"] ||= match_strategy.presence || inferred_match_strategy(plan, dto)
      mapping
    end

    def inferred_match_strategy(plan, dto)
      return "enrollment_benefit_id" if dto.remote_plan_id.present? && (plan.vitable_id == dto.remote_plan_id || plan.vitable_id.blank?)

      "enrollment_benefit_name"
    end

    def normalize(value)
      value.to_s.downcase.gsub(/[^a-z0-9]+/, "")
    end
  end
end
