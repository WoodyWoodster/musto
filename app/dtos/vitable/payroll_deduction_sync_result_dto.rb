module Vitable
  PayrollDeductionSyncResultDto = Data.define(:created_ids, :updated_ids, :unchanged_ids) do
    def self.empty
      new(created_ids: [], updated_ids: [], unchanged_ids: [])
    end

    def merge(other)
      self.class.new(
        created_ids: created_ids + other.created_ids,
        updated_ids: updated_ids + other.updated_ids,
        unchanged_ids: unchanged_ids + other.unchanged_ids
      )
    end

    def changed_ids
      created_ids + updated_ids
    end

    def changed_count
      changed_ids.count
    end

    def to_metadata
      {
        "created_count" => created_ids.count,
        "updated_count" => updated_ids.count,
        "unchanged_count" => unchanged_ids.count,
        "changed_ids" => changed_ids
      }
    end
  end
end
