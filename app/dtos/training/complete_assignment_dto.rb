module Training
  CompleteAssignmentDto = Data.define(:id, :completed_by, :score) do
    def self.from_params(params)
      raw = ApplicationDto.coerce_hash(params)
      raw_score = raw.fetch("score", nil)

      new(
        id: raw.fetch("id").to_i,
        completed_by: raw.fetch("completed_by", "ops_console"),
        score: raw_score.present? ? raw_score.to_i : nil
      )
    end
  end
end
