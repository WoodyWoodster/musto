module Payroll
  class RunDetailQuery
    def initialize(repository: PayrollRepository.new)
      @repository = repository
    end

    def call(id)
      RunDetailDto.from_record(@repository.find_detail(id))
    end
  end
end
