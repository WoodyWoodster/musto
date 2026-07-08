module Vitable
  class PlanYearWebhookReconciliationRepository < ApplicationRepository
    SNAPSHOT_KEY = "vitable_plan_year_snapshots"

    def initialize(event:)
      @event = event
      @connection = event.integration_connection
    end

    def call
      dto = RemotePlanYearDto.from_event(@event)
      employer, matched_by = employer_match(dto)
      return unmatched(dto) unless employer
      return missing_year(employer, matched_by) if dto.year.blank?

      applied_changes = []
      warnings = []
      applied_changes << update_employer(employer, dto)
      plan_changes = update_benefit_plans(employer, dto)
      campaign_change = update_open_enrollment_campaign(employer, dto)
      applied_changes.concat(plan_changes)
      applied_changes << campaign_change if campaign_change
      warnings << "No local benefit plans matched plan year #{dto.year}." if plan_changes.empty?
      warnings << "No local open enrollment campaign matched plan year #{dto.year}." unless campaign_change

      WebhookResourceReconciliationDto.new(
        status: "matched",
        resource_type: @event.resource_type,
        resource_id: @event.resource_id,
        local_record_type: "Employer",
        local_record_id: employer.id,
        matched_by:,
        applied_changes: applied_changes.compact_blank,
        warnings:
      )
    end

    private

    def unmatched(dto)
      WebhookResourceReconciliationDto.new(
        status: "unmatched",
        resource_type: @event.resource_type,
        resource_id: @event.resource_id,
        local_record_type: nil,
        local_record_id: nil,
        matched_by: nil,
        applied_changes: [],
        warnings: [ "No local employer matched this Vitable plan year payload for #{dto.remote_employer_id || dto.employer_reference_id || "the event organization"}." ]
      )
    end

    def missing_year(employer, matched_by)
      WebhookResourceReconciliationDto.new(
        status: "skipped",
        resource_type: @event.resource_type,
        resource_id: @event.resource_id,
        local_record_type: "Employer",
        local_record_id: employer.id,
        matched_by:,
        applied_changes: [],
        warnings: [ "Vitable plan year payload did not include a plan year or parseable start date." ]
      )
    end

    def employer_match(dto)
      if dto.remote_employer_id.present?
        employer = employer_scope.find_by(vitable_id: dto.remote_employer_id)
        return [ employer, "remote_employer_id" ] if employer
      end

      employer = employer_from_reference_id(dto.employer_reference_id)
      return [ employer, "employer_reference_id" ] if employer

      employers = employer_scope.to_a
      return [ employers.first, "single_employer" ] if employers.one?

      [ nil, nil ]
    end

    def employer_from_reference_id(reference_id)
      value = reference_id.to_s
      return unless value.match?(/\Amusto_employer_\d+\z/)

      employer_scope.find_by(id: value.delete_prefix("musto_employer_").to_i)
    end

    def update_employer(employer, dto)
      snapshots = employer.settings.to_h.stringify_keys.fetch(SNAPSHOT_KEY, {}).to_h
      snapshots[snapshot_key(dto)] = dto.snapshot_hash.merge(
        "last_webhook_event_id" => @event.event_id,
        "last_webhook_event_name" => @event.event_name,
        "last_refreshed_at" => Time.current.iso8601
      )
      employer.update!(
        settings: employer.settings.to_h.stringify_keys.merge(
          SNAPSHOT_KEY => snapshots,
          "vitable_last_plan_year_webhook_event_id" => @event.event_id,
          "vitable_last_plan_year_refreshed_at" => Time.current.iso8601
        )
      )

      "employer.settings.#{SNAPSHOT_KEY}"
    end

    def update_benefit_plans(employer, dto)
      employer.benefit_plans.where(plan_year: dto.year).map do |plan|
        attributes = {
          metadata: plan.metadata.to_h.stringify_keys.merge(
            "vitable_plan_year_id" => dto.remote_plan_year_id,
            "vitable_plan_year_status" => dto.status,
            "vitable_plan_year_snapshot" => dto.snapshot_hash,
            "vitable_plan_year_last_webhook_event_id" => @event.event_id,
            "vitable_plan_year_refreshed_at" => Time.current.iso8601
          ).compact
        }
        attributes[:effective_on] = dto.starts_on if dto.starts_on.present? && plan.effective_on != dto.starts_on
        attributes[:expires_on] = dto.ends_on if dto.ends_on.present? && plan.expires_on != dto.ends_on
        plan.update!(attributes)
        "benefit_plans.#{plan.id}"
      end
    end

    def update_open_enrollment_campaign(employer, dto)
      campaign = employer.open_enrollment_campaigns.find_by(plan_year: dto.year)
      return unless campaign

      attributes = {
        metadata: campaign.metadata.to_h.stringify_keys.merge(
          "vitable_plan_year_id" => dto.remote_plan_year_id,
          "vitable_plan_year_status" => dto.status,
          "vitable_plan_year_snapshot" => dto.snapshot_hash,
          "vitable_plan_year_last_webhook_event_id" => @event.event_id,
          "vitable_plan_year_refreshed_at" => Time.current.iso8601
        ).compact
      }
      attributes[:starts_on] = dto.open_enrollment_starts_on if dto.open_enrollment_starts_on.present? && campaign.starts_on != dto.open_enrollment_starts_on
      attributes[:ends_on] = dto.open_enrollment_ends_on if dto.open_enrollment_ends_on.present? && campaign.ends_on != dto.open_enrollment_ends_on
      attributes[:status] = campaign_status(dto.status) if campaign_status(dto.status).present? && campaign.status != campaign_status(dto.status)
      campaign.update!(attributes)

      "open_enrollment_campaigns.#{campaign.id}"
    end

    def campaign_status(status)
      normalized = status.to_s.downcase
      return "active" if normalized.in?(%w[active open current])
      return "closed" if normalized.in?(%w[closed ended complete completed])
      return "archived" if normalized.in?(%w[archived inactive])

      "draft" if normalized.in?(%w[draft pending upcoming])
    end

    def snapshot_key(dto)
      dto.remote_plan_year_id.presence || dto.year.to_s
    end

    def employer_scope
      @connection.organization.employers
    end
  end
end
