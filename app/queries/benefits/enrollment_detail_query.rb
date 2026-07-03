module Benefits
  class EnrollmentDetailQuery
    def initialize(repository: BenefitsRepository.new(employer: nil))
      @repository = repository
    end

    def call(id)
      EnrollmentDetailDto.from_record(@repository.find_detail(id))
    end
  end
end
