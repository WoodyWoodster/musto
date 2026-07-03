module PayStatements
  CenterDto = Data.define(
    :employer,
    :metrics,
    :payroll_run,
    :statements,
    :delivery_issues,
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

    def deliverable_statements
      statements.select(&:generated?)
    end

    def delivered_statements
      statements.select(&:delivered?)
    end
  end
end
