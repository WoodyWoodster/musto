module Contractors
  class ContractorRepository < ApplicationRepository
    def initialize(employer: nil)
      @employer = employer
    end

    def contractors
      return Contractor.none unless @employer

      @employer.contractors.includes(:contractor_payments).order(:last_name, :first_name)
    end

    def payments
      return ContractorPayment.none unless @employer

      ContractorPayment
        .joins(:contractor)
        .where(contractors: { employer_id: @employer.id })
        .includes(:contractor)
        .order(pay_date: :desc, created_at: :desc)
    end

    def batches
      payload = @employer&.settings.to_h.fetch("contractor_payment_batch", nil)
      payload.present? ? [ payload ] : []
    end

    def find_payment(id)
      ContractorPayment.includes(:contractor).find(id)
    end

    def approve_payment(payment, reviewed_by:)
      unless payment.contractor.ready_for_payment?
        payment.block!(reason: "Contractor tax form and verified payment method are required before approval")
        return false
      end

      payment.approve!(reviewed_by:)
    end

    def generate_payment_batch(requested_by:)
      all_payments = payments.to_a
      approved_payments = all_payments.select(&:approved?)
      holdbacks = all_payments.reject(&:approved?)
      lines = payment_lines(approved_payments)

      batch = {
        "batch_id" => "contractor_payments_#{@employer.id}_#{Time.current.to_i}",
        "generated_at" => Time.current.iso8601,
        "requested_by" => requested_by,
        "employer_id" => @employer.id,
        "status" => lines.any? && holdbacks.empty? ? "ready" : "needs_review",
        "totals" => {
          "payment_count" => lines.count,
          "contractor_count" => approved_payments.map(&:contractor_id).uniq.count,
          "holdback_count" => holdbacks.count,
          "total_cents" => lines.sum { |line| line.fetch("amount_cents") }
        },
        "payments" => lines,
        "holdbacks" => holdbacks.map { |payment| holdback_line(payment) }
      }

      @employer.update!(settings: @employer.settings.to_h.merge("contractor_payment_batch" => batch))
      batch
    end

    private

    def payment_lines(payments)
      payments.map do |payment|
        {
          "payment_id" => payment.id,
          "contractor_id" => payment.contractor_id,
          "contractor_name" => payment.contractor.full_name,
          "business_name" => payment.contractor.business_name,
          "description" => payment.description,
          "payment_method" => payment.payment_method,
          "pay_date" => payment.pay_date.iso8601,
          "amount_cents" => payment.amount_cents
        }
      end
    end

    def holdback_line(payment)
      {
        "payment_id" => payment.id,
        "contractor_id" => payment.contractor_id,
        "contractor_name" => payment.contractor.full_name,
        "description" => payment.description,
        "status" => payment.status,
        "amount_cents" => payment.amount_cents,
        "reason" => holdback_reason(payment)
      }
    end

    def holdback_reason(payment)
      return "Payment is not approved" unless payment.approved?
      return "Contractor is not active" unless payment.contractor.status == "active"
      return "Tax form is not complete" unless payment.contractor.tax_form_status == "complete"
      return "Payment method is not verified" unless payment.contractor.payment_method_status == "verified"

      "Ready"
    end
  end
end
