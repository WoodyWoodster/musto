module Benefits
  PublishPlanDto = Data.define(:plan_id, :published_by) do
    def self.from_params(params)
      attributes = ApplicationDto.coerce_hash(params)

      new(
        plan_id: attributes.fetch(:id) { attributes.fetch("id") }.to_i,
        published_by: attributes.fetch(:published_by) { attributes.fetch("published_by", "benefits_admin") }
      )
    end
  end
end
