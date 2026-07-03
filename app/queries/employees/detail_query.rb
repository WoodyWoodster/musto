module Employees
  class DetailQuery
    def initialize(repository: EmployeeRepository.new)
      @repository = repository
    end

    def call(id)
      ProfileDto.from_record(@repository.find_profile(id))
    end
  end
end
