module Expenses
  CenterDto = Data.define(
    :employer,
    :metrics,
    :expenses,
    :policy_items,
    :batches,
    :batch_lines,
    :batch_holdbacks,
    :batch_payload
  ) do
    def generated?
      batch_payload.present?
    end

    def latest_batch
      batches.first
    end

    def submitted_expenses
      expenses.select(&:submitted?)
    end

    def approved_expenses
      expenses.select(&:approved?)
    end

    def reviewable_expenses
      expenses.select(&:policy_ready?)
    end
  end
end
