module Employers
  class CreateEmployerCommand < ApplicationCommand
    def initialize(dto:)
      @dto = dto
    end

    def call
      employer = Employer.new(@dto.to_attributes)

      if employer.save
        success(record: employer)
      else
        failure(record: employer, errors: employer.errors.full_messages)
      end
    end
  end
end
