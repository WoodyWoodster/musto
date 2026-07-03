module OpenEnrollment
  class CampaignRepository < ApplicationRepository
    def initialize(employer: nil)
      @employer = employer
    end

    def campaigns
      return OpenEnrollmentCampaign.none unless @employer

      @employer
        .open_enrollment_campaigns
        .includes(open_enrollment_invitations: [ employee: [ :department, :work_location, :enrollments, :dependents ] ])
        .current_first
    end

    def current_campaign
      campaigns.first
    end

    def employees
      return Employee.none unless @employer

      @employer
        .employees
        .active
        .includes(:department, :work_location, :dependents, enrollments: [ :benefit_plan ])
        .order(:last_name, :first_name)
    end

    def plans
      return BenefitPlan.none unless @employer

      @employer.benefit_plans.includes(:enrollments).order(:category, :name)
    end

    def enrollments
      return Enrollment.none unless @employer

      Enrollment
        .joins(:employee)
        .where(employees: { employer_id: @employer.id })
        .includes(:benefit_plan, :payroll_deductions, employee: [ :department, :work_location, :dependents ])
    end

    def dependents
      return Dependent.none unless @employer

      Dependent
        .joins(:employee)
        .where(employees: { employer_id: @employer.id })
        .includes(:employee)
    end

    def invitations
      campaign = current_campaign
      return OpenEnrollmentInvitation.none unless campaign

      campaign
        .open_enrollment_invitations
        .includes(employee: [ :department, :work_location, :dependents, enrollments: [ :benefit_plan ] ])
        .order(:due_on, :status)
    end

    def batches
      payload = current_campaign&.metadata.to_h.fetch("open_enrollment_batch", nil)
      payload.present? ? [ payload ] : []
    end

    def launch_campaign(requested_by:)
      campaign = current_campaign || create_campaign
      timestamp = Time.current
      sent = []
      holdbacks = []

      campaign.launch!(requested_by:)

      employees.each do |employee|
        invitation = campaign.open_enrollment_invitations.find_or_initialize_by(employee:)
        invitation.due_on ||= campaign.ends_on

        if invitation.completed? || invitation.waived?
          holdbacks << holdback_line(invitation, reason: "Employee already completed or waived this enrollment window")
        else
          invitation.assign_attributes(
            status: "sent",
            sent_at: invitation.sent_at || timestamp,
            metadata: invitation.metadata.to_h.merge(
              "sent_by" => requested_by,
              "sent_at" => timestamp.iso8601,
              "channel" => "employee_portal"
            )
          )
          invitation.save!
          sent << batch_line(invitation)
        end
      end

      batch = batch_payload(
        batch_type: "launch",
        requested_by:,
        timestamp:,
        sent:,
        reminders: [],
        holdbacks:
      )
      campaign.update!(metadata: campaign.metadata.to_h.merge("open_enrollment_batch" => batch))
      batch
    end

    def send_reminders(requested_by:)
      campaign = current_campaign || create_campaign
      timestamp = Time.current
      reminders = []
      holdbacks = []

      campaign.open_enrollment_invitations.includes(:employee).find_each do |invitation|
        if invitation.remindable?
          invitation.update!(
            status: "reminded",
            last_reminded_at: timestamp,
            metadata: invitation.metadata.to_h.merge(
              "last_reminded_by" => requested_by,
              "last_reminded_at" => timestamp.iso8601,
              "reminder_count" => invitation.metadata.to_h.fetch("reminder_count", 0).to_i + 1
            )
          )
          reminders << batch_line(invitation)
        else
          holdbacks << holdback_line(invitation, reason: "Invitation is #{invitation.status.humanize.downcase} and cannot be reminded")
        end
      end

      batch = batch_payload(
        batch_type: "reminder",
        requested_by:,
        timestamp:,
        sent: [],
        reminders:,
        holdbacks:
      )
      campaign.update!(reminders_sent_at: timestamp, metadata: campaign.metadata.to_h.merge("open_enrollment_batch" => batch))
      batch
    end

    private

    def create_campaign
      plan_year = Date.current.year + 1
      starts_on = Date.current.next_month.beginning_of_month
      ends_on = starts_on + 21.days

      @employer.open_enrollment_campaigns.create!(
        name: "#{plan_year} Open Enrollment",
        plan_year:,
        starts_on:,
        ends_on:,
        status: "draft",
        metadata: { "source" => "generated_open_enrollment" }
      )
    end

    def batch_payload(batch_type:, requested_by:, timestamp:, sent:, reminders:, holdbacks:)
      {
        "batch_id" => "open_enrollment_#{batch_type}_#{@employer.id}_#{timestamp.to_i}",
        "batch_type" => batch_type,
        "generated_at" => timestamp.iso8601,
        "requested_by" => requested_by,
        "employer_id" => @employer.id,
        "status" => holdbacks.any? ? "needs_review" : "ready",
        "totals" => {
          "sent_count" => sent.count,
          "reminder_count" => reminders.count,
          "holdback_count" => holdbacks.count
        },
        "lines" => sent + reminders,
        "holdbacks" => holdbacks
      }
    end

    def batch_line(invitation)
      {
        "invitation_id" => invitation.id,
        "employee_id" => invitation.employee_id,
        "employee_name" => invitation.employee.full_name,
        "status" => invitation.status,
        "due_on" => invitation.due_on.iso8601,
        "sent_at" => invitation.sent_at&.iso8601,
        "last_reminded_at" => invitation.last_reminded_at&.iso8601
      }
    end

    def holdback_line(invitation, reason:)
      {
        "invitation_id" => invitation.id,
        "employee_id" => invitation.employee_id,
        "employee_name" => invitation.employee.full_name,
        "reason" => reason,
        "status" => invitation.status
      }
    end
  end
end
