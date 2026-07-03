module Employers
  class OverviewQuery
    def initialize(repository: EmployerRepository.new)
      @repository = repository
    end

    def call
      @repository.overview.map { |employer| EmployerSummaryDto.from_record(employer) }
    end
  end
end
