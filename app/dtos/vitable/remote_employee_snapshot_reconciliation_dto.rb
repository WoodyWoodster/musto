module Vitable
  RemoteEmployeeSnapshotReconciliationDto = Data.define(
    :processed_count,
    :matched_count,
    :updated_count,
    :unchanged_count,
    :unmatched_count,
    :unmatched_employer_count,
    :deduction_sync,
    :lifecycle_reconciliation
  ) do
    def self.empty
      new(
        processed_count: 0,
        matched_count: 0,
        updated_count: 0,
        unchanged_count: 0,
        unmatched_count: 0,
        unmatched_employer_count: 0,
        deduction_sync: PayrollDeductionSyncResultDto.empty,
        lifecycle_reconciliation: EmployeeLifecycleReconciliationDto.empty
      )
    end

    def increment(processed_count: 0, matched_count: 0, updated_count: 0, unchanged_count: 0, unmatched_count: 0, unmatched_employer_count: 0, deduction_sync: PayrollDeductionSyncResultDto.empty, lifecycle_reconciliation: EmployeeLifecycleReconciliationDto.empty)
      self.class.new(
        processed_count: self.processed_count + processed_count,
        matched_count: self.matched_count + matched_count,
        updated_count: self.updated_count + updated_count,
        unchanged_count: self.unchanged_count + unchanged_count,
        unmatched_count: self.unmatched_count + unmatched_count,
        unmatched_employer_count: self.unmatched_employer_count + unmatched_employer_count,
        deduction_sync: self.deduction_sync.merge(deduction_sync),
        lifecycle_reconciliation: self.lifecycle_reconciliation.merge(lifecycle_reconciliation)
      )
    end

    def to_metadata
      {
        "processed_count" => processed_count,
        "matched_count" => matched_count,
        "updated_count" => updated_count,
        "unchanged_count" => unchanged_count,
        "unmatched_count" => unmatched_count,
        "unmatched_employer_count" => unmatched_employer_count,
        "deduction_sync" => deduction_sync.to_metadata,
        "lifecycle_reconciliation" => lifecycle_reconciliation.to_metadata
      }
    end
  end
end
