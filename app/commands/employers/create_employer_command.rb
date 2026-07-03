module Employers
  class CreateEmployerCommand < ApplicationCommand
    def initialize(dto:, repository: EmployerRepository.new)
      @dto = dto
      @repository = repository
    end

    def call
      employer = @repository.create(@dto)

      if employer.persisted?
        success(record: employer)
      else
        failure(record: employer, errors: employer.errors.full_messages)
      end
    end
  end
end
