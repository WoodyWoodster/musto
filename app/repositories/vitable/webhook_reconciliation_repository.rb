module Vitable
  class WebhookReconciliationRepository < ApplicationRepository
    ACCEPTED_ENROLLMENT_STATUSES = %w[accepted elected enrolled active].freeze
    PENDING_ENROLLMENT_STATUSES = %w[pending started granted].freeze
    WAIVED_ENROLLMENT_STATUSES = %w[waived declined].freeze
    INACTIVE_ENROLLMENT_STATUSES = %w[inactive terminated canceled cancelled].freeze

    def initialize(event:, response_hash:)
      @event = event
      @response_hash = response_hash.to_h.stringify_keys
    end

    def call
      remote_resource = response_resource(@response_hash)
      return reconciliation_result(status: "skipped", warnings: [ "Fetched resource response did not include attributes." ]) if remote_resource.blank?

      validate_remote_resource_identity!(remote_resource)

      case @event.resource_type
      when "employee"
        reconcile_employee_resource(remote_resource)
      when "enrollment"
        reconcile_enrollment_resource(remote_resource)
      when "employer"
        reconcile_employer_resource(remote_resource)
      when "group"
        reconcile_group_resource(remote_resource)
      when "webhook_event"
        reconcile_webhook_event_resource(remote_resource)
      else
        reconciliation_result(status: "skipped", remote_resource:, warnings: [ "#{@event.resource_type} webhooks are stored as snapshots only." ])
      end
    rescue ActiveRecord::RecordInvalid => e
      reconciliation_result(status: "failed", remote_resource:, local_record: e.record, warnings: e.record.errors.full_messages)
    end

    private

    def reconcile_employee_resource(remote_resource)
      employee, matched_by = employee_match_for(remote_resource)
      return reconciliation_result(status: "unmatched", remote_resource:, warnings: [ "No local employee matched this Vitable resource." ]) unless employee

      remote_id = remote_resource_id(remote_resource)
      return remote_id_conflict_result(remote_resource, employee, matched_by) if remote_id_conflict?(employee, remote_id)

      timestamp = Time.current.iso8601
      applied_changes = []
      update_attributes = {}

      if remote_id.present? && employee.vitable_id != remote_id
        update_attributes[:vitable_id] = remote_id
        applied_changes << "vitable_id"
      end
      local_employment_status = employee_employment_status_for(remote_resource)
      if local_employment_status.present? && employee.employment_status != local_employment_status
        update_attributes[:employment_status] = local_employment_status
        applied_changes << "employment_status"
      end
      remote_hire_date = remote_employee_hire_date(remote_resource)
      if remote_hire_date.present? && employee.start_on != remote_hire_date
        update_attributes[:start_on] = remote_hire_date
        applied_changes << "start_on"
      end

      metadata_updates = {
        "vitable_remote_status" => remote_resource.fetch("status", nil),
        "vitable_member_id" => remote_resource.fetch("member_id", nil),
        "vitable_remote_employee_class" => remote_resource.fetch("employee_class", nil),
        "vitable_remote_hire_date" => remote_hire_date&.iso8601,
        "vitable_remote_termination_date" => remote_employee_termination_date(remote_resource)&.iso8601,
        "vitable_remote_date_of_birth" => remote_date(remote_resource, "date_of_birth")&.iso8601,
        "vitable_remote_phone" => remote_resource.fetch("phone", nil),
        "vitable_remote_address" => remote_employee_address(remote_resource),
        "vitable_last_refreshed_at" => timestamp,
        "vitable_last_webhook_event_id" => @event.event_id,
        "vitable_last_webhook_event_name" => @event.event_name,
        "vitable_last_resource_snapshot" => remote_resource_summary(
          remote_resource,
          %w[id reference_id email first_name last_name status member_id employee_class hire_date termination_date date_of_birth phone]
        )
      }.merge(employee_event_metadata(remote_resource, timestamp)).compact

      update_attributes[:metadata] = employee.metadata.to_h.stringify_keys.merge(metadata_updates)
      applied_changes.concat(metadata_updates.keys.map { |key| "metadata.#{key}" })
      employee.update!(update_attributes)
      applied_changes.concat(apply_employee_payroll_deductions(employee, remote_resource, timestamp))
      applied_changes.concat(deactivate_employee_benefits(employee, remote_resource, timestamp).applied_changes)

      reconciliation_result(status: "matched", remote_resource:, local_record: employee, matched_by:, applied_changes:)
    end

    def reconcile_enrollment_resource(remote_resource)
      enrollment, matched_by = enrollment_match_for(remote_resource)
      return reconciliation_result(status: "unmatched", remote_resource:, warnings: [ "No local enrollment matched this Vitable resource." ]) unless enrollment

      remote_id = remote_resource_id(remote_resource)
      return remote_id_conflict_result(remote_resource, enrollment, matched_by) if remote_id_conflict?(enrollment, remote_id)

      timestamp = Time.current.iso8601
      remote_status = remote_resource.fetch("status", nil).presence || @event.event_name.to_s.split(".").last
      local_status = local_enrollment_status(remote_status)
      applied_changes = []
      update_attributes = {}

      if remote_id.present? && enrollment.vitable_id != remote_id
        update_attributes[:vitable_id] = remote_id
        applied_changes << "vitable_id"
      end

      if local_status.present? && enrollment.status != local_status
        update_attributes[:status] = local_status
        update_attributes[:accepted_at] = local_status == "accepted" ? (remote_time(remote_resource, "answered_at") || enrollment.accepted_at || Time.current) : nil
        applied_changes << "status"
        applied_changes << "accepted_at"
      elsif local_status == "accepted" && enrollment.accepted_at.blank?
        update_attributes[:accepted_at] = remote_time(remote_resource, "answered_at") || Time.current
        applied_changes << "accepted_at"
      end

      if remote_date(remote_resource, "coverage_start").present? && enrollment.effective_on != remote_date(remote_resource, "coverage_start")
        update_attributes[:effective_on] = remote_date(remote_resource, "coverage_start")
        applied_changes << "effective_on"
      end

      metadata_updates = {
        "vitable_remote_status" => remote_status,
        "vitable_remote_employee_id" => remote_employee_id(remote_resource),
        "vitable_remote_plan_id" => remote_plan_id(remote_resource),
        "vitable_remote_benefit" => remote_benefit_summary(remote_resource),
        "vitable_remote_answered_at" => remote_time(remote_resource, "answered_at")&.iso8601,
        "vitable_remote_coverage_start" => remote_date(remote_resource, "coverage_start")&.iso8601,
        "vitable_remote_coverage_end" => remote_date(remote_resource, "coverage_end")&.iso8601,
        "vitable_remote_terminated_at" => remote_time(remote_resource, "terminated_at")&.iso8601,
        "vitable_employee_deduction_cents" => remote_resource.fetch("employee_deduction_in_cents", nil),
        "vitable_employer_contribution_cents" => remote_resource.fetch("employer_contribution_in_cents", nil),
        "vitable_last_refreshed_at" => timestamp,
        "vitable_last_webhook_event_id" => @event.event_id,
        "vitable_last_webhook_event_name" => @event.event_name,
        "vitable_last_resource_snapshot" => remote_resource_summary(remote_resource, %w[id status employee_id member_id plan_id product_id coverage_start coverage_end employee_deduction_in_cents employer_contribution_in_cents])
      }.compact

      update_attributes[:metadata] = enrollment.metadata.to_h.stringify_keys.merge(metadata_updates)
      applied_changes.concat(metadata_updates.keys.map { |key| "metadata.#{key}" })
      enrollment.update!(update_attributes)
      plan_sync = benefit_plan_snapshot_repository.sync_from_remote_enrollment(
        enrollment:,
        dto: RemoteEnrollmentDto.from_hash(remote_resource),
        source: "vitable_webhook",
        refreshed_at: timestamp,
        match_strategy: matched_by
      )
      applied_changes.concat(plan_sync.applied_changes)
      applied_changes.concat(apply_enrollment_payroll_deductions(enrollment, local_status, remote_resource, timestamp))

      reconciliation_result(status: "matched", remote_resource:, local_record: enrollment, matched_by:, applied_changes:)
    end

    def reconcile_employer_resource(remote_resource)
      employer, matched_by = employer_match_for(remote_resource)
      return reconciliation_result(status: "unmatched", remote_resource:, warnings: [ "No local employer matched this Vitable resource." ]) unless employer

      remote_id = remote_resource_id(remote_resource)
      return remote_id_conflict_result(remote_resource, employer, matched_by) if remote_id_conflict?(employer, remote_id)

      timestamp = Time.current.iso8601
      applied_changes = []
      update_attributes = {}

      if remote_id.present? && employer.vitable_id != remote_id
        update_attributes[:vitable_id] = remote_id
        applied_changes << "vitable_id"
      end

      settings_updates = {
        "vitable_remote_status" => remote_resource.fetch("status", nil),
        "vitable_last_refreshed_at" => timestamp,
        "vitable_last_webhook_event_id" => @event.event_id,
        "vitable_last_webhook_event_name" => @event.event_name,
        "vitable_remote_employer" => remote_resource_summary(remote_resource, %w[id reference_id external_reference_id name legal_name status])
      }.merge(employer_event_settings(remote_resource, timestamp)).compact

      update_attributes[:settings] = employer.settings.to_h.stringify_keys.merge(settings_updates)
      applied_changes.concat(settings_updates.keys.map { |key| "settings.#{key}" })
      employer.update!(update_attributes)

      reconciliation_result(status: "matched", remote_resource:, local_record: employer, matched_by:, applied_changes:)
    end

    def reconcile_group_resource(remote_resource)
      employer, matched_by = group_employer_match_for(remote_resource)
      return reconciliation_result(status: "unmatched", remote_resource:, warnings: [ "No local employer matched this Vitable group." ]) unless employer

      remote_id = remote_resource_id(remote_resource)
      local_group_id = care_group_id_for(employer)
      if local_group_id.present? && remote_id.present? && local_group_id != remote_id
        return reconciliation_result(
          status: "conflict",
          remote_resource:,
          local_record: employer,
          matched_by:,
          warnings: [ "Employer #{employer.id} is already linked to #{local_group_id}." ]
        )
      end

      timestamp = Time.current.iso8601
      settings_updates = {
        CareGroupRepository::GROUP_ID_KEY => remote_id,
        "vitable_care_group_remote_reference_id" => group_remote_reference_id(remote_resource),
        "vitable_care_group_last_refreshed_at" => timestamp,
        "vitable_care_group_last_webhook_event_id" => @event.event_id,
        "vitable_care_group_last_webhook_event_name" => @event.event_name,
        "vitable_care_group_snapshot_source" => "vitable_webhook_resource",
        "vitable_care_group_snapshot_matched_by" => matched_by,
        RemoteGroupSnapshotRepository::SNAPSHOT_KEY => remote_resource_summary(
          remote_resource,
          %w[id organization_id name external_reference_id created_at updated_at]
        ).merge(
          "matched_by" => matched_by,
          "source" => "vitable_webhook_resource",
          "refreshed_at" => timestamp
        )
      }.compact
      settings = employer.settings.to_h.stringify_keys.merge(settings_updates)
      settings.delete(RemoteGroupSnapshotRepository::CONFLICT_KEY)
      employer.update!(settings:)

      reconciliation_result(
        status: "matched",
        remote_resource:,
        local_record: employer,
        matched_by:,
        applied_changes: settings_updates.keys.map { |key| "settings.#{key}" }
      )
    end

    def reconcile_webhook_event_resource(remote_resource)
      expected_organization_id = webhook_event_connection_organization_id
      validate_remote_webhook_event_identity!(remote_resource)
      dto = RemoteWebhookEventDto.from_remote_event(remote_resource)
      return reconciliation_result(status: "skipped", remote_resource:, warnings: [ "Fetched webhook event response did not include a complete Vitable event." ]) unless dto
      return webhook_event_organization_mismatch_result(remote_resource, dto, expected_organization_id) if webhook_event_organization_mismatch?(dto, expected_organization_id)

      webhook_event = WebhookEvent.find_or_initialize_by(event_id: dto.event_id)
      was_new_record = webhook_event.new_record?
      timestamp = Time.current.iso8601
      metadata = webhook_event.metadata.to_h.merge(
        "remote_webhook_event_snapshot" => {
          "source" => "vitable_resource_fetch",
          "fetched_at" => timestamp,
          "resource_id" => @event.resource_id
        }.compact
      )

      webhook_event.assign_attributes(dto.to_event_attributes)
      webhook_event.integration_connection ||= @event.integration_connection
      webhook_event.status = "received" if webhook_event.status.blank?
      webhook_event.metadata = metadata
      webhook_event.save!

      reconciliation_result(
        status: "matched",
        remote_resource:,
        local_record: webhook_event,
        matched_by: was_new_record ? "created_from_event_id" : "event_id",
        applied_changes: [ was_new_record ? "webhook_events.created" : "webhook_events.updated", "metadata.remote_webhook_event_snapshot" ]
      )
    end

    def webhook_event_connection_organization_id
      @event.integration_connection&.organization&.external_id.presence
    end

    def validate_remote_webhook_event_identity!(remote_resource)
      remote_event_id = remote_resource.fetch("event_id", nil).presence || remote_resource.fetch("id", nil).presence
      raise ArgumentError, "Vitable webhook event response did not include a remote webhook event ID" if remote_event_id.blank?
      if @event.resource_id.present? && remote_event_id != @event.resource_id
        raise ArgumentError, "Vitable webhook event response returned remote webhook event ID #{remote_event_id}, expected #{@event.resource_id}"
      end

      missing_fields = {
        "organization_id" => remote_webhook_event_organization_id(remote_resource),
        "event_name" => remote_resource.fetch("event_name", nil),
        "resource_type" => remote_resource.fetch("resource_type", nil),
        "resource_id" => remote_resource.fetch("resource_id", nil),
        "created_at" => remote_resource.fetch("created_at", nil).presence || remote_resource.fetch("occurred_at", nil).presence
      }.filter_map { |field, value| field if value.blank? }
      raise ArgumentError, "Vitable webhook event #{remote_event_id} did not include #{missing_fields.to_sentence}" if missing_fields.any?
    end

    def remote_webhook_event_organization_id(remote_resource)
      remote_resource.fetch("organization_id", nil).presence ||
        remote_resource.fetch("organization_external_id", nil).presence
    end

    def webhook_event_organization_mismatch?(dto, expected_organization_id)
      expected_organization_id.present? && dto.organization_id.present? && dto.organization_id != expected_organization_id
    end

    def webhook_event_organization_mismatch_result(remote_resource, dto, expected_organization_id)
      reconciliation_result(
        status: "skipped",
        remote_resource:,
        warnings: [ "Fetched webhook event belongs to Vitable organization #{dto.organization_id}, not #{expected_organization_id}." ]
      )
    end

    def response_resource(response_hash)
      RemoteResourceResponseDto
        .from_response(response_hash, resource_type: @event.resource_type, resource_id: @event.resource_id)
        .validate!
        .attributes
    end

    def employee_match_for(remote_resource)
      remote_id = remote_resource_id(remote_resource)
      scope = employee_scope

      if remote_id.present?
        employee = scope.find_by(vitable_id: remote_id)
        return [ employee, "vitable_id" ] if employee
      end

      employee = employee_from_reference_id(scope, remote_resource.fetch("reference_id", nil))
      return [ employee, "reference_id" ] if employee

      email = remote_resource.fetch("email", nil).presence
      if email
        employee = employee_by_email(scope, email)
        return [ employee, "email" ] if employee
      end

      [ nil, nil ]
    end

    def enrollment_match_for(remote_resource)
      remote_id = remote_resource_id(remote_resource)
      scope = enrollment_scope

      if remote_id.present?
        enrollment = scope.find_by(vitable_id: remote_id)
        return [ enrollment, "vitable_id" ] if enrollment
      end

      enrollment = enrollment_from_reference_id(scope, remote_resource.fetch("reference_id", nil))
      return [ enrollment, "reference_id" ] if enrollment

      employee = employee_by_remote_id(remote_employee_id(remote_resource))
      dto = RemoteEnrollmentDto.from_hash(remote_resource)
      plan = plan_by_remote_id(remote_plan_id(remote_resource))
      plan_matched_by = plan ? "plan_id" : nil
      if employee && !plan
        plan, plan_matched_by = benefit_plan_snapshot_repository.find_for_remote_enrollment(employer: employee.employer, dto:)
      end
      if employee && plan
        enrollment = employee.enrollments.find_by(benefit_plan: plan)
        return [ enrollment, "employee_id+#{plan_matched_by}" ] if enrollment
      end

      [ nil, nil ]
    end

    def employer_match_for(remote_resource)
      remote_id = remote_resource_id(remote_resource)
      scope = employer_scope

      if remote_id.present?
        employer = scope.find_by(vitable_id: remote_id)
        return [ employer, "vitable_id" ] if employer
      end

      reference_id = remote_resource.fetch("reference_id", nil).presence || remote_resource.fetch("external_reference_id", nil)
      employer = employer_from_reference_id(scope, reference_id)
      return [ employer, "reference_id" ] if employer

      employers = scope.to_a
      return [ employers.first, "single_employer_connection" ] if employers.one?

      [ nil, nil ]
    end

    def group_employer_match_for(remote_resource)
      remote_id = remote_resource_id(remote_resource)
      employers = employer_scope.to_a

      if remote_id.present?
        employer = employers.find { |record| care_group_id_for(record) == remote_id }
        return [ employer, "care_group_id" ] if employer
      end

      employer = employer_from_care_group_reference_id(remote_resource)
      return [ employer, "external_reference_id" ] if employer

      name = remote_resource.fetch("name", nil).to_s.strip.downcase.presence
      if name
        matches = employers.select { |employer_record| employer_record.name.to_s.strip.downcase == name }
        return [ matches.first, "name" ] if matches.one?
      end

      [ nil, nil ]
    end

    def employee_scope
      Employee.where(employer_id: employer_scope.select(:id))
    end

    def employer_scope
      @event.integration_connection&.organization&.employers || Employer.none
    end

    def enrollment_scope
      Enrollment.joins(:employee).where(employees: { employer_id: employer_scope.select(:id) })
    end

    def plan_scope
      BenefitPlan.where(employer_id: employer_scope.select(:id))
    end

    def employee_from_reference_id(scope, reference_id)
      value = reference_id.to_s
      return unless value.match?(/\Amusto_employee_\d+\z/)

      scope.find_by(id: value.delete_prefix("musto_employee_").to_i)
    end

    def employee_by_email(scope, email)
      normalized = email.to_s.downcase.presence
      return if normalized.blank?

      matches = scope.select { |employee| employee.email.to_s.downcase == normalized }
      matches.one? ? matches.first : nil
    end

    def enrollment_from_reference_id(scope, reference_id)
      value = reference_id.to_s
      return unless value.match?(/\Amusto_enrollment_\d+\z/)

      scope.find_by(id: value.delete_prefix("musto_enrollment_").to_i)
    end

    def employer_from_reference_id(scope, reference_id)
      value = reference_id.to_s
      return unless value.match?(/\Amusto_employer_\d+\z/)

      scope.find_by(id: value.delete_prefix("musto_employer_").to_i)
    end

    def employer_from_care_group_reference_id(remote_resource)
      value = group_remote_reference_id(remote_resource).to_s
      return unless value.match?(/\Amusto_care_group_\d+\z/)

      employer_scope.find_by(id: value.delete_prefix("musto_care_group_").to_i)
    end

    def care_group_id_for(employer)
      employer.settings.to_h.stringify_keys.fetch(CareGroupRepository::GROUP_ID_KEY, nil).presence
    end

    def group_remote_reference_id(remote_resource)
      remote_resource.fetch("external_reference_id", nil).presence || remote_resource.fetch("reference_id", nil).presence
    end

    def employee_by_remote_id(remote_id)
      return if remote_id.blank?

      employee_scope.find_by(vitable_id: remote_id)
    end

    def plan_by_remote_id(remote_id)
      return if remote_id.blank?

      plan_scope.find_by(vitable_id: remote_id)
    end

    def remote_id_conflict?(record, remote_id)
      record.vitable_id.present? && remote_id.present? && record.vitable_id != remote_id
    end

    def remote_id_conflict_result(remote_resource, record, matched_by)
      reconciliation_result(
        status: "conflict",
        remote_resource:,
        local_record: record,
        matched_by:,
        warnings: [ "#{record.class.name} #{record.id} is already linked to #{record.vitable_id}." ]
      )
    end

    def remote_resource_id(remote_resource)
      remote_resource.fetch("id", nil).presence || @event.resource_id
    end

    def validate_remote_resource_identity!(remote_resource)
      return unless @event.resource_type.in?(%w[employee enrollment employer group])

      reference = remote_resource.fetch("reference_id", nil).presence ||
        remote_resource.fetch("external_reference_id", nil).presence ||
        remote_resource.fetch("email", nil).presence ||
        remote_resource.fetch("name", nil).presence ||
        @event.resource_id
      raise ArgumentError, "Vitable #{@event.resource_type} resource #{reference} did not include a remote resource ID" if remote_resource.fetch("id", nil).blank?
      if @event.resource_id.present? && remote_resource.fetch("id") != @event.resource_id
        raise ArgumentError, "Vitable #{@event.resource_type} resource #{reference} returned remote resource ID #{remote_resource.fetch("id")}, expected #{@event.resource_id}"
      end

      case @event.resource_type
      when "employee"
        raise ArgumentError, "Vitable employee resource #{reference} did not include a remote member ID" if remote_resource.fetch("member_id", nil).blank?
      when "enrollment"
        raise ArgumentError, "Vitable enrollment resource #{reference} did not include a remote employee ID" if remote_resource.fetch("employee_id", nil).blank?
        raise ArgumentError, "Vitable enrollment resource #{reference} did not include a remote benefit ID" if remote_resource.dig("benefit", "id").blank?
      end
    end

    def remote_employee_id(remote_resource)
      remote_resource.fetch("employee_id", nil).presence ||
        remote_resource.fetch("member_id", nil).presence ||
        remote_resource.dig("employee", "id").presence
    end

    def remote_plan_id(remote_resource)
      remote_resource.fetch("plan_id", nil).presence ||
        remote_resource.fetch("product_id", nil).presence ||
        remote_resource.dig("benefit", "id").presence ||
        remote_resource.dig("plan", "id").presence
    end

    def local_enrollment_status(remote_status)
      normalized = remote_status.to_s.downcase
      return "accepted" if normalized.in?(ACCEPTED_ENROLLMENT_STATUSES)
      return "pending" if normalized.in?(PENDING_ENROLLMENT_STATUSES)
      return "waived" if normalized.in?(WAIVED_ENROLLMENT_STATUSES)
      return "inactive" if normalized.in?(INACTIVE_ENROLLMENT_STATUSES)

      nil
    end

    def remote_benefit_summary(remote_resource)
      benefit = remote_resource.fetch("benefit", nil)
      return unless benefit.respond_to?(:to_h)

      benefit.to_h.stringify_keys.slice("id", "name", "category", "product_code").compact
    end

    def benefit_plan_snapshot_repository
      @benefit_plan_snapshot_repository ||= BenefitPlanSnapshotRepository.new
    end

    def remote_date(remote_resource, key)
      value = remote_resource.fetch(key, nil)
      return value if value.is_a?(Date)
      return value.to_date if value.respond_to?(:to_date)
      return if value.blank?

      Date.iso8601(value.to_s)
    rescue ArgumentError
      nil
    end

    def remote_time(remote_resource, key)
      value = remote_resource.fetch(key, nil)
      return value if value.respond_to?(:iso8601)
      return if value.blank?

      Time.iso8601(value.to_s)
    rescue ArgumentError
      nil
    end

    def remote_employee_hire_date(remote_resource)
      remote_date(remote_resource, "hire_date") || remote_date(remote_resource, "start_date")
    end

    def remote_employee_termination_date(remote_resource)
      remote_date(remote_resource, "termination_date") || remote_date(remote_resource, "terminated_on")
    end

    def remote_employee_address(remote_resource)
      address = remote_resource.fetch("address", nil)
      return unless address.respond_to?(:to_h)

      address.to_h.stringify_keys.slice("address_line_1", "address_line_2", "city", "state", "zipcode").compact
    end

    def apply_enrollment_payroll_deductions(enrollment, local_status, remote_resource, timestamp)
      return [] unless local_status.present?

      dto = RemoteEnrollmentDto.from_hash(enrollment_resource_with_event_status(remote_resource))
      return [] unless dto.active_deduction? || enrollment.payroll_deductions.exists?

      result = PayrollDeductionRepository.new.sync_employee_deductions(
        employee: enrollment.employee,
        remote_deductions: [ dto.deduction_payload(enrollment) ],
        source: "vitable_webhook_resource",
        source_event: @event,
        reconciled_at: timestamp
      )
      result.changed_ids.map { |id| "payroll_deductions.#{id}" }
    end

    def enrollment_resource_with_event_status(remote_resource)
      remote_resource.merge(
        "status" => remote_resource.fetch("status", nil).presence || @event.event_name.to_s.split(".").last
      )
    end

    def employee_event_metadata(remote_resource, timestamp)
      case @event.event_name
      when "employee.eligibility_granted"
        {
          "vitable_eligibility_status" => "granted",
          "vitable_eligibility_changed_at" => timestamp
        }
      when "employee.eligibility_terminated"
        {
          "vitable_eligibility_status" => "terminated",
          "vitable_eligibility_changed_at" => timestamp
        }
      when "employee.deactivated"
        {
          "vitable_lifecycle_status" => "deactivated",
          "vitable_lifecycle_changed_at" => timestamp
        }
      when "employee.deduction_created"
        {
          "vitable_last_deduction_event_at" => timestamp,
          "vitable_remote_deductions" => remote_resource.fetch("deductions", []),
          "vitable_last_deduction" => remote_resource_summary(remote_resource, %w[id status deduction_type amount_cents starts_on])
        }
      else
        {}
      end
    end

    def employee_employment_status_for(remote_resource)
      normalized = remote_resource.fetch("status", nil).to_s.downcase
      return "terminated" if normalized.in?(%w[inactive deactivated terminated])
      return "active" if normalized.in?(%w[active reactivated])
      return "terminated" if @event.event_name == "employee.deactivated"

      nil
    end

    def employer_event_settings(remote_resource, timestamp)
      return {} unless @event.event_name == "employer.eligibility_policy_created"

      {
        "vitable_eligibility_policy_last_event" => {
          "event_id" => @event.event_id,
          "resource_id" => @event.resource_id,
          "recorded_at" => timestamp,
          "remote_status" => remote_resource.fetch("status", nil)
        }.compact
      }
    end

    def remote_resource_summary(remote_resource, keys)
      remote_resource.slice(*keys).compact
    end

    def apply_employee_payroll_deductions(employee, remote_resource, timestamp)
      result = PayrollDeductionRepository.new.sync_employee_deductions(
        employee:,
        remote_deductions: remote_resource.fetch("deductions", []),
        source: "vitable_webhook_resource",
        source_event: @event,
        reconciled_at: timestamp
      )
      result.changed_ids.map { |id| "payroll_deductions.#{id}" }
    end

    def deactivate_employee_benefits(employee, remote_resource, timestamp)
      return EmployeeLifecycleReconciliationDto.empty unless deactivate_employee_benefits?(remote_resource)

      EmployeeEligibilityRepository.new.deactivate_benefits!(
        employee:,
        source: "vitable_webhook_resource",
        source_event: @event,
        reconciled_at: timestamp
      )
    end

    def deactivate_employee_benefits?(remote_resource)
      employee_employment_status_for(remote_resource) == "terminated" ||
        @event.event_name == "employee.eligibility_terminated"
    end

    def reconciliation_result(status:, remote_resource: nil, local_record: nil, matched_by: nil, applied_changes: [], warnings: [])
      WebhookResourceReconciliationDto.new(
        status:,
        resource_type: @event.resource_type,
        resource_id: remote_resource ? remote_resource_id(remote_resource) : @event.resource_id,
        local_record_type: local_record&.class&.name,
        local_record_id: local_record&.id,
        matched_by:,
        applied_changes: Array(applied_changes).compact.uniq,
        warnings: Array(warnings).compact
      )
    end
  end
end
