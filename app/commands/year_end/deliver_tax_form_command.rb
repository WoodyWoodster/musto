module YearEnd
  class DeliverTaxFormCommand < ApplicationCommand
    def initialize(dto:, employer_repository: Employers::EmployerRepository.new, repository: nil)
      @dto = dto
      @employer = employer_repository.first_for_operations
      @repository = repository || TaxFormRepository.new(employer: @employer, tax_year: @dto.tax_year)
    end

    def call
      return failure(errors: "No employer is available for year-end tax form delivery") unless @employer

      form = @repository.find_form(@dto.form_id)
      return failure(record: form, errors: "Year-end tax form is not ready for delivery") unless form.deliverable?

      @repository.deliver_form(form, delivered_by: @dto.delivered_by)
      success(record: form.reload)
    rescue ActiveRecord::RecordNotFound
      failure(errors: "Year-end tax form was not found")
    rescue ActiveRecord::RecordInvalid => e
      failure(record: e.record, errors: e.record.errors.full_messages)
    end
  end
end
