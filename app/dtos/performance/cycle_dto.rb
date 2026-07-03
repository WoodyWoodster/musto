module Performance
  CycleDto = Data.define(:id, :name, :status, :review_type, :period_start_on, :period_end_on, :due_on, :launched_at, :review_count, :completed_count, :calibration_count, :open_count) do
    def self.from_record(record)
      reviews = record.performance_reviews

      new(
        id: record.id,
        name: record.name,
        status: record.status,
        review_type: record.review_type,
        period_start_on: record.period_start_on,
        period_end_on: record.period_end_on,
        due_on: record.due_on,
        launched_at: record.launched_at,
        review_count: reviews.size,
        completed_count: reviews.count(&:complete?),
        calibration_count: reviews.count(&:calibration?),
        open_count: reviews.count { |review| !review.complete? }
      )
    end
  end
end
