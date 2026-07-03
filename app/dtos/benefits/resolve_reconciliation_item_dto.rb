module Benefits
  ResolveReconciliationItemDto = Data.define(:enrollment_id) do
    def self.from_params(params)
      new(enrollment_id: ApplicationDto.id_from(params, :enrollment_id))
    end
  end
end
