module Vitable
  EnrollmentSnapshotReconciliationDto = Data.define(
    :processed_count,
    :matched_count,
    :created_count,
    :updated_count,
    :unchanged_count,
    :unmatched_count,
    :missing_plan_count,
    :deduction_sync
  ) do
    def self.empty
      new(
        processed_count: 0,
        matched_count: 0,
        created_count: 0,
        updated_count: 0,
        unchanged_count: 0,
        unmatched_count: 0,
        missing_plan_count: 0,
        deduction_sync: PayrollDeductionSyncResultDto.empty
      )
    end

    def increment(processed_count: 0, matched_count: 0, created_count: 0, updated_count: 0, unchanged_count: 0, unmatched_count: 0, missing_plan_count: 0, deduction_sync: PayrollDeductionSyncResultDto.empty)
      self.class.new(
        processed_count: self.processed_count + processed_count,
        matched_count: self.matched_count + matched_count,
        created_count: self.created_count + created_count,
        updated_count: self.updated_count + updated_count,
        unchanged_count: self.unchanged_count + unchanged_count,
        unmatched_count: self.unmatched_count + unmatched_count,
        missing_plan_count: self.missing_plan_count + missing_plan_count,
        deduction_sync: self.deduction_sync.merge(deduction_sync)
      )
    end

    def to_metadata
      {
        "processed_count" => processed_count,
        "matched_count" => matched_count,
        "created_count" => created_count,
        "updated_count" => updated_count,
        "unchanged_count" => unchanged_count,
        "unmatched_count" => unmatched_count,
        "missing_plan_count" => missing_plan_count,
        "deduction_sync" => deduction_sync.to_metadata
      }
    end
  end
end
