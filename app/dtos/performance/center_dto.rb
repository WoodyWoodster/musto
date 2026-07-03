module Performance
  CenterDto = Data.define(:employer, :metrics, :cycles, :reviews, :goals, :issues, :calibration_batches, :calibration_lines, :calibration_holdbacks, :calibration_payload) do
    def current_cycle
      cycles.find { |cycle| cycle.status.in?(%w[active calibration]) } || cycles.first
    end

    def latest_batch
      calibration_batches.first
    end

    def calibratable_reviews
      reviews.select(&:calibratable?)
    end

    def open_goals
      goals.select(&:completable?)
    end
  end
end
