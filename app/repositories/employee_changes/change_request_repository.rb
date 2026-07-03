module EmployeeChanges
  class ChangeRequestRepository < ApplicationRepository
    def initialize(employer: nil)
      @employer = employer
    end

    def requests
      return EmployeeChangeRequest.none unless @employer

      EmployeeChangeRequest
        .joins(:employee)
        .where(employees: { employer_id: @employer.id })
        .includes(employee: [ :department, :work_location ])
        .order(status: :asc, submitted_at: :desc, created_at: :desc)
    end

    def batches
      payload = @employer&.settings.to_h.fetch("employee_change_sync_batch", nil)
      payload.present? ? [ payload ] : []
    end

    def find_request(id)
      scope = EmployeeChangeRequest.includes(employee: [ :employer, :department, :work_location ])
      scope = scope.joins(:employee).where(employees: { employer_id: @employer.id }) if @employer
      scope.find(id)
    end

    def approve_request(request, reviewed_by:)
      return false unless request.reviewable?

      EmployeeChangeRequest.transaction do
        apply_request(request)
        request.update!(
          status: "applied",
          reviewed_at: Time.current,
          reviewed_by:,
          applied_at: Time.current,
          metadata: request.metadata.to_h.merge(
            "reviewed_by" => reviewed_by,
            "reviewed_at" => Time.current.iso8601,
            "applied_at" => Time.current.iso8601
          )
        )
      end
    end

    def reject_request(request, reviewed_by:, reason:)
      return false unless request.reviewable?

      request.update!(
        status: "rejected",
        reviewed_at: Time.current,
        reviewed_by:,
        rejected_at: Time.current,
        metadata: request.metadata.to_h.merge(
          "reviewed_by" => reviewed_by,
          "reviewed_at" => Time.current.iso8601,
          "rejected_reason" => reason
        )
      )
    end

    def generate_sync_batch(requested_by:)
      applied_requests = requests.applied.to_a
      submitted_requests = requests.submitted.to_a
      lines = applied_requests.map { |request| sync_line(request) }
      holdbacks = submitted_requests.map { |request| holdback_line(request, reason: "Request is still waiting for approval") }
      holdbacks << empty_holdback("No applied employee changes are ready for sync") if lines.empty?
      batch = batch_payload(lines:, holdbacks:, requested_by:)

      EmployeeChangeRequest.transaction do
        @employer.update!(settings: @employer.settings.to_h.merge("employee_change_sync_batch" => batch))
        applied_requests.each { |request| request.queue_for_sync!(batch_id: batch.fetch("batch_id")) }
      end

      batch
    end

    private

    def apply_request(request)
      case request.request_type
      when "direct_deposit"
        apply_direct_deposit(request)
      when "tax_withholding"
        apply_tax_withholding(request)
      when "emergency_contact"
        merge_employee_metadata(request, "emergency_contact")
      when "profile_update"
        merge_employee_metadata(request, "profile_update")
      when "work_location"
        apply_work_location(request)
      end
    end

    def apply_direct_deposit(request)
      employee = request.employee
      payload = request.payload
      employee.employee_bank_accounts.primary_accounts.each { |account| account.update!(primary_account: false) }
      employee.employee_bank_accounts.create!(
        nickname: payload.fetch("nickname", "Self-service direct deposit"),
        institution_name: payload.fetch("institution_name"),
        account_type: payload.fetch("account_type", "checking"),
        routing_number_last4: payload.fetch("routing_number_last4"),
        account_last4: payload.fetch("account_last4"),
        allocation_type: payload.fetch("allocation_type", "remainder"),
        allocation_value: payload.fetch("allocation_value", 100),
        status: "prenote_sent",
        verification_method: "prenote",
        primary_account: true,
        prenote_sent_at: Time.current,
        metadata: { source: "employee_change_request", employee_change_request_id: request.id }
      )
    end

    def apply_tax_withholding(request)
      employee = request.employee
      payload = request.payload
      employee.update!(metadata: employee.metadata.to_h.merge("tax_withholding" => payload.merge("updated_from_request_id" => request.id)))
      document = employee.employee_documents.find_or_initialize_by(title: "Updated Form W-4", document_type: "tax")
      document.assign_attributes(
        status: "complete",
        issued_on: Date.current,
        verified_at: Time.current,
        source: "employee_portal",
        metadata: document.metadata.to_h.merge(
          "source" => "employee_change_request",
          "employee_change_request_id" => request.id,
          "withholding_payload" => payload
        )
      )
      document.save!
    end

    def apply_work_location(request)
      employee = request.employee
      location = employee.employer.work_locations.find_by(id: request.payload.fetch("work_location_id", nil))
      unless location
        request.errors.add(:base, "Requested work location is not available for this employer")
        raise ActiveRecord::RecordInvalid, request
      end

      employee.update!(
        work_location: location,
        metadata: employee.metadata.to_h.merge(
          "work_location_change_request_id" => request.id,
          "work_location_changed_at" => Time.current.iso8601
        )
      )
    end

    def merge_employee_metadata(request, key)
      employee = request.employee
      employee.update!(
        metadata: employee.metadata.to_h.merge(
          key => request.payload.merge(
            "updated_from_request_id" => request.id,
            "updated_at" => Time.current.iso8601
          )
        )
      )
    end

    def batch_payload(lines:, holdbacks:, requested_by:)
      {
        "batch_id" => "employee_changes_#{@employer.id}_#{Time.current.to_i}",
        "generated_at" => Time.current.iso8601,
        "requested_by" => requested_by,
        "employer_id" => @employer.id,
        "status" => lines.any? && holdbacks.empty? ? "ready" : "needs_review",
        "totals" => {
          "request_count" => lines.count,
          "employee_count" => lines.map { |line| line.fetch("employee_id") }.uniq.count,
          "payroll_impact_count" => lines.count { |line| line.fetch("payroll_impact") != "none" },
          "benefits_impact_count" => lines.count { |line| line.fetch("benefits_impact") != "none" },
          "holdback_count" => holdbacks.count
        },
        "requests" => lines,
        "holdbacks" => holdbacks
      }
    end

    def sync_line(request)
      employee = request.employee
      {
        "request_id" => request.id,
        "employee_id" => employee.id,
        "employee_name" => employee.full_name,
        "remote_employee_id" => employee.vitable_id.presence || "pending_employee_#{employee.id}",
        "request_type" => request.request_type,
        "effective_on" => request.effective_on.iso8601,
        "title" => request.title,
        "payroll_impact" => request.payroll_impact,
        "benefits_impact" => request.benefits_impact,
        "compliance_impact" => request.compliance_impact,
        "status" => "sync_queued",
        "changes" => request.payload
      }
    end

    def holdback_line(request, reason:)
      {
        "request_id" => request.id,
        "employee_name" => request.employee.full_name,
        "request_type" => request.request_type,
        "reason" => reason,
        "status" => request.status
      }
    end

    def empty_holdback(reason)
      {
        "request_id" => nil,
        "employee_name" => "Employee self-service",
        "request_type" => "profile_changes",
        "reason" => reason,
        "status" => "needs_review"
      }
    end
  end
end
