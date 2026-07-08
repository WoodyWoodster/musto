module Vitable
  EligibilityPolicySnapshotReconciliationDto = Data.define(
    :processed_count,
    :matched_count,
    :updated_count,
    :unchanged_count,
    :unmatched_count,
    :error_count
  ) do
    def self.empty
      new(
        processed_count: 0,
        matched_count: 0,
        updated_count: 0,
        unchanged_count: 0,
        unmatched_count: 0,
        error_count: 0
      )
    end

    def increment(processed_count: 0, matched_count: 0, updated_count: 0, unchanged_count: 0, unmatched_count: 0, error_count: 0)
      self.class.new(
        processed_count: self.processed_count + processed_count,
        matched_count: self.matched_count + matched_count,
        updated_count: self.updated_count + updated_count,
        unchanged_count: self.unchanged_count + unchanged_count,
        unmatched_count: self.unmatched_count + unmatched_count,
        error_count: self.error_count + error_count
      )
    end

    def to_metadata
      {
        "processed_count" => processed_count,
        "matched_count" => matched_count,
        "updated_count" => updated_count,
        "unchanged_count" => unchanged_count,
        "unmatched_count" => unmatched_count,
        "error_count" => error_count
      }
    end
  end
end
