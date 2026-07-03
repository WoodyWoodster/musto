module Contractors
  class CenterQuery
    def initialize(employer_repository: Employers::EmployerRepository.new)
      @employer = employer_repository.first_for_operations
      @repository = ContractorRepository.new(employer: @employer)
    end

    def call
      contractors = @repository.contractors.to_a
      payments = @repository.payments.to_a
      batches = @repository.batches
      latest_batch = batches.first.to_h

      CenterDto.new(
        employer: Operations::EmployerContextDto.from_record(@employer),
        metrics: metrics(contractors, payments),
        contractors: contractors.map { |contractor| ContractorDto.from_record(contractor) },
        payments: payments.map { |payment| PaymentDto.from_record(payment) },
        readiness_items: readiness_items(contractors, payments),
        batches: batches.map { |payload| BatchDto.from_hash(payload) },
        batch_payments: latest_batch.fetch("payments", []).map { |payload| BatchPaymentDto.from_hash(payload) },
        batch_holdbacks: latest_batch.fetch("holdbacks", []).map { |payload| BatchHoldbackDto.from_hash(payload) },
        batch_payload: batches.first
      )
    end

    private

    def metrics(contractors, payments)
      active_count = contractors.count { |contractor| contractor.status == "active" }
      draft_count = payments.count(&:draft?)
      approved_total = payments.select(&:approved?).sum(&:amount_cents)
      ready_count = contractors.count(&:ready_for_payment?)

      [
        MetricDto.new(label: "Active contractors", value: active_count, hint: "#{contractors.count} in contractor roster", status: active_count.positive? ? "ready" : "needs_review", accent: "bg-pink-500", format: "number"),
        MetricDto.new(label: "Approval queue", value: draft_count, hint: "draft payments need review", status: draft_count.positive? ? "needs_review" : "ready", accent: "bg-amber-500", format: "number"),
        MetricDto.new(label: "Approved pay", value: approved_total, hint: "ready for contractor batch", status: approved_total.positive? ? "ready" : "needs_review", accent: "bg-emerald-500", format: "money"),
        MetricDto.new(label: "Payment-ready", value: ready_count, hint: "tax and payment method complete", status: ready_count == contractors.count ? "ready" : "needs_review", accent: "bg-cyan-500", format: "number")
      ]
    end

    def readiness_items(contractors, payments)
      routes = Rails.application.routes.url_helpers
      items = []
      missing_tax_forms = contractors.count { |contractor| contractor.tax_form_status != "complete" }
      missing_payment_methods = contractors.count { |contractor| contractor.payment_method_status != "verified" }
      draft_payments = payments.count(&:draft?)
      blocked_payments = payments.count { |payment| payment.status == "blocked" }

      if missing_tax_forms.positive?
        items << ReadinessItemDto.new(key: "tax_forms", title: "Collect contractor tax forms", detail: "#{missing_tax_forms} contractors need W-9 or tax form completion before payment approval.", severity: "high", status: "needs_review", owner: "People", action_path: routes.contractors_path)
      end

      if missing_payment_methods.positive?
        items << ReadinessItemDto.new(key: "payment_methods", title: "Verify payment methods", detail: "#{missing_payment_methods} contractors need a verified ACH or check payment method.", severity: "medium", status: "needs_review", owner: "Finance", action_path: routes.contractors_path)
      end

      if draft_payments.positive?
        items << ReadinessItemDto.new(key: "approval_queue", title: "Approve contractor payments", detail: "#{draft_payments} draft payments are waiting for operations review.", severity: "medium", status: "needs_review", owner: "Finance", action_path: routes.contractors_path)
      end

      if blocked_payments.positive?
        items << ReadinessItemDto.new(key: "blocked_payments", title: "Resolve blocked payments", detail: "#{blocked_payments} payments are blocked by missing contractor readiness.", severity: "high", status: "blocked", owner: "Finance", action_path: routes.contractors_path)
      end

      return items if items.any?

      [
        ReadinessItemDto.new(key: "contractors_ready", title: "Contractor payroll is batch-ready", detail: "All contractor payment records have the tax and payment method data needed for export.", severity: "low", status: "ready", owner: "Finance", action_path: routes.generate_contractor_payment_batch_path)
      ]
    end
  end
end
