module Dashboard
  class DashboardRepository < ApplicationRepository
    def open_onboarding_count
      OnboardingTask.open.count
    end

    def pending_time_off_count
      TimeOffRequest.pending.count
    end

    def urgent_compliance_count
      ComplianceCase.urgent.count
    end

    def benefits_participation_rate
      total = Enrollment.count
      return 0 if total.zero?

      ((Enrollment.accepted.count.to_f / total) * 100).round
    end

    def upcoming_payroll
      PayrollRun.order(pay_date: :asc).where(pay_date: Date.current..).first
    end

    def recent_activity
      [
        *WebhookEvent.order(created_at: :desc).limit(4).map { |event| [ "Webhook", event.event_name, event.status, event.created_at ] },
        *PayrollRun.order(updated_at: :desc).limit(3).map { |run| [ "Payroll", "Pay date #{run.pay_date}", run.status, run.updated_at ] },
        *ComplianceCase.order(updated_at: :desc).limit(3).map { |item| [ "Compliance", item.kind.titleize, item.status, item.updated_at ] }
      ].sort_by(&:last).reverse.first(8)
    end
  end
end
