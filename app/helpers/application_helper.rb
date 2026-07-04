module ApplicationHelper
  def nav_item(label, path)
    active = current_page?(path)
    classes = [
      "group flex shrink-0 items-center justify-between gap-3 whitespace-nowrap rounded-md px-3 py-2 text-sm font-medium transition lg:shrink",
      active ? "bg-[#f4f3ff] text-[#635bff] ring-1 ring-inset ring-[#635bff]/15" : "text-slate-600 hover:bg-slate-50 hover:text-slate-950"
    ].join(" ")

    link_to path, class: classes, aria: (active ? { current: "page" } : nil) do
      tag.span(label, class: "truncate") +
        tag.span("", class: "h-1.5 w-1.5 shrink-0 rounded-full #{active ? "bg-[#635bff]" : "bg-transparent"}")
    end
  end

  def status_pill(status)
    normalized = status.to_s
    palette = case normalized
    when "active", "available", "accepted", "approved", "complete", "completed", "processed", "succeeded", "finalized", "ready", "connected", "verified", "paid", "eligible", "enrolled", "synced", "funded", "delivered", "viewed", "matched", "hired", "on_track", "closed", "resolved", "response_ready", "electronic_consented", "certificate_ready", "forecast_ready", "published", "medical_only", "first_aid", "low"
      "bg-emerald-50 text-emerald-700 ring-emerald-200"
    when "pending", "requested", "received", "reported", "investigating", "onboarding", "estimated", "open", "running", "in_progress", "in_review", "scheduled", "remote_pending", "sync_queued", "queued", "prenote_sent", "sent", "opened", "reminded", "applied", "screening", "interview", "offer", "self_review", "manager_review", "calibration", "assigned", "withheld"
      "bg-cyan-50 text-cyan-700 ring-cyan-200"
    when "needs_credentials", "waiting_on_enrollment", "needs_review", "renewal_due", "draft", "not_synced", "waived", "unmatched_organization", "missing", "pending_verification", "variance", "missing_deduction", "not_sent", "not_requested", "paper_required", "due_soon", "paused", "skipped", "empty", "submitted", "not_configured", "not_recorded", "lost_time", "medium"
      "bg-amber-50 text-amber-800 ring-amber-200"
    when "failed", "expired", "denied", "critical", "high", "blocked", "overdue", "escalated", "rejected", "withdrawn", "at_risk", "missed", "correction_needed", "coverage_gap", "missing_signature", "signature_invalid", "serious"
      "bg-rose-50 text-rose-700 ring-rose-200"
    else
      "bg-slate-100 text-slate-700 ring-slate-200"
    end

    tag.span(normalized.to_s.humanize, class: "inline-flex items-center rounded-full px-2.5 py-1 text-xs font-semibold ring-1 ring-inset #{palette}")
  end

  def operator_name(identifier)
    normalized = identifier.to_s.presence || "Musto Operations"
    {
      "ops_console" => "Musto Operations",
      "Musto Operations" => "Musto Operations",
      "people_ops" => "People Operations",
      "people_ops_admin" => "People Operations",
      "payroll_ops" => "Payroll Team",
      "payroll_admin" => "Payroll Team",
      "benefits_admin" => "Benefits Team",
      "compliance_ops" => "Compliance Team",
      "compliance_admin" => "Compliance Team",
      "tax_ops" => "Tax Team",
      "finance_admin" => "Finance Team",
      "preview" => "Preview"
    }.fetch(normalized, normalized.tr("_", " ").titleize)
  end

  def money_cents(value)
    number_to_currency(value.to_i / 100.0, precision: 0)
  end

  def compact_number(value)
    number_with_delimiter(value.to_i)
  end
end
