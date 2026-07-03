module ApplicationHelper
  def nav_item(label, path, accent: "bg-cyan-500")
    active = current_page?(path)
    classes = [
      "group flex items-center gap-3 rounded-md px-3 py-2 text-sm font-medium transition",
      active ? "bg-slate-950 text-white shadow-sm" : "text-slate-600 hover:bg-white hover:text-slate-950 hover:shadow-sm"
    ].join(" ")

    link_to path, class: classes do
      tag.span("", class: "h-2.5 w-2.5 rounded-full #{active ? "bg-white" : accent}") +
        tag.span(label)
    end
  end

  def status_pill(status)
    normalized = status.to_s
    palette = case normalized
    when "active", "available", "accepted", "approved", "complete", "completed", "processed", "succeeded", "finalized", "ready", "connected", "verified", "paid", "eligible", "enrolled", "synced", "funded", "delivered", "viewed", "matched", "hired", "on_track", "closed", "certificate_ready"
      "bg-emerald-50 text-emerald-700 ring-emerald-200"
    when "pending", "requested", "received", "onboarding", "estimated", "open", "running", "in_progress", "scheduled", "remote_pending", "sync_queued", "prenote_sent", "sent", "opened", "reminded", "applied", "screening", "interview", "offer", "self_review", "manager_review", "calibration", "assigned", "withheld"
      "bg-cyan-50 text-cyan-700 ring-cyan-200"
    when "needs_credentials", "waiting_on_enrollment", "needs_review", "draft", "not_synced", "waived", "unmatched_organization", "missing", "pending_verification", "variance", "missing_deduction", "not_sent", "due_soon", "paused", "skipped", "empty", "submitted"
      "bg-amber-50 text-amber-800 ring-amber-200"
    when "failed", "expired", "denied", "critical", "high", "blocked", "overdue", "rejected", "withdrawn", "at_risk"
      "bg-rose-50 text-rose-700 ring-rose-200"
    else
      "bg-slate-100 text-slate-700 ring-slate-200"
    end

    tag.span(normalized.to_s.humanize, class: "inline-flex items-center rounded-full px-2.5 py-1 text-xs font-semibold ring-1 ring-inset #{palette}")
  end

  def money_cents(value)
    number_to_currency(value.to_i / 100.0, precision: 0)
  end

  def compact_number(value)
    number_with_delimiter(value.to_i)
  end
end
