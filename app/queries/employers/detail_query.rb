module Employers
  class DetailQuery
    def initialize(repository: EmployerRepository.new)
      @repository = repository
    end

    def call(id)
      EmployerDetailDto.from_record(@repository.find_detail(id))
    end
  end
end
