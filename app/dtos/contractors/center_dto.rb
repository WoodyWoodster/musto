module Contractors
  CenterDto = Data.define(
    :employer,
    :metrics,
    :contractors,
    :payments,
    :readiness_items,
    :batches,
    :batch_payments,
    :batch_holdbacks,
    :batch_payload
  ) do
    def generated?
      batch_payload.present?
    end

    def latest_batch
      batches.first
    end

    def pending_payments
      payments.select(&:draft?)
    end

    def approved_payments
      payments.select(&:approved?)
    end
  end
end
