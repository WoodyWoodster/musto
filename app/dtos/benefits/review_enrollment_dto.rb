module Benefits
  ReviewEnrollmentDto = Data.define(:enrollment_id, :decision) do
    def self.from_params(params, decision:)
      new(enrollment_id: ApplicationDto.id_from(params), decision:)
    end
  end
end
