module Vitable
  DependentSnapshotSyncResultDto = Data.define(
    :processed_count,
    :matched_count,
    :created_ids,
    :updated_ids,
    :unchanged_ids,
    :missing_required_count
  ) do
    def self.empty
      new(
        processed_count: 0,
        matched_count: 0,
        created_ids: [],
        updated_ids: [],
        unchanged_ids: [],
        missing_required_count: 0
      )
    end

    def merge(other)
      self.class.new(
        processed_count: processed_count + other.processed_count,
        matched_count: matched_count + other.matched_count,
        created_ids: created_ids + other.created_ids,
        updated_ids: updated_ids + other.updated_ids,
        unchanged_ids: unchanged_ids + other.unchanged_ids,
        missing_required_count: missing_required_count + other.missing_required_count
      )
    end

    def record_processed
      self.class.new(
        processed_count: processed_count + 1,
        matched_count:,
        created_ids:,
        updated_ids:,
        unchanged_ids:,
        missing_required_count:
      )
    end

    def record_missing_required
      self.class.new(
        processed_count:,
        matched_count:,
        created_ids:,
        updated_ids:,
        unchanged_ids:,
        missing_required_count: missing_required_count + 1
      )
    end

    def record_created(id)
      record_matched(created_ids: created_ids + [ id ])
    end

    def record_updated(id)
      record_matched(updated_ids: updated_ids + [ id ])
    end

    def record_unchanged(id)
      record_matched(unchanged_ids: unchanged_ids + [ id ])
    end

    def changed_ids
      created_ids + updated_ids
    end

    def changed_count
      changed_ids.count
    end

    def to_reconciliation_attributes
      {
        dependent_processed_count: processed_count,
        dependent_matched_count: matched_count,
        dependent_created_count: created_ids.count,
        dependent_updated_count: updated_ids.count,
        dependent_unchanged_count: unchanged_ids.count,
        dependent_missing_required_count: missing_required_count
      }
    end

    def to_metadata
      {
        "processed_count" => processed_count,
        "matched_count" => matched_count,
        "created_count" => created_ids.count,
        "updated_count" => updated_ids.count,
        "unchanged_count" => unchanged_ids.count,
        "changed_count" => changed_count,
        "missing_required_count" => missing_required_count,
        "created_ids" => created_ids,
        "updated_ids" => updated_ids,
        "unchanged_ids" => unchanged_ids,
        "changed_ids" => changed_ids
      }
    end

    private

    def record_matched(created_ids: self.created_ids, updated_ids: self.updated_ids, unchanged_ids: self.unchanged_ids)
      self.class.new(
        processed_count:,
        matched_count: matched_count + 1,
        created_ids:,
        updated_ids:,
        unchanged_ids:,
        missing_required_count:
      )
    end
  end
end
