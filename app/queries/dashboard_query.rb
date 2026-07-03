class DashboardQuery
  def call
    {
      employer: Employer.includes(:organization).order(:created_at).first,
      employers: Employer.includes(:organization).order(created_at: :desc),
      active_employee_count: Employee.active.count,
      payroll_ready_count: Employee.active.where.not(compensation_cents: 0).count,
      open_onboarding_count: OnboardingTask.open.count,
      pending_time_off_count: TimeOffRequest.pending.count,
      compliance_urgent_count: ComplianceCase.urgent.count,
      benefits_participation_rate: benefits_participation_rate,
      recent_activity: recent_activity,
      upcoming_payroll: PayrollRun.order(pay_date: :asc).where(pay_date: Date.current..).first,
      integration_health: integration_health
    }
  end

  private

  def benefits_participation_rate
    total = Enrollment.count
    return 0 if total.zero?

    ((Enrollment.accepted.count.to_f / total) * 100).round
  end

  def integration_health
    {
      active: IntegrationConnection.where(status: "active").count,
      needs_credentials: IntegrationConnection.where(status: "needs_credentials").count,
      pending_webhooks: WebhookEvent.unprocessed.count
    }
  end

  def recent_activity
    [
      *WebhookEvent.order(created_at: :desc).limit(4).map { |event| [ "Webhook", event.event_name, event.status, event.created_at ] },
      *PayrollRun.order(updated_at: :desc).limit(3).map { |run| [ "Payroll", "Pay date #{run.pay_date}", run.status, run.updated_at ] },
      *ComplianceCase.order(updated_at: :desc).limit(3).map { |item| [ "Compliance", item.kind.titleize, item.status, item.updated_at ] }
    ].sort_by(&:last).reverse.first(8)
  end
end
