module Performance
  CalibrateReviewDto = Data.define(:review_id, :calibrated_by) do
    def self.from_params(params)
      attributes = ApplicationDto.coerce_hash(params)

      new(
        review_id: ApplicationDto.id_from(params),
        calibrated_by: attributes.fetch("calibrated_by", "ops_console")
      )
    end
  end
end
