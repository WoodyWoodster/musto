module Documents
  EmployeeCoverageDto = Data.define(
    :employee_id,
    :employee_name,
    :department_name,
    :location_name,
    :coverage_percent,
    :required_count,
    :complete_count,
    :attention_count,
    :missing_titles,
    :status
  ) do
    def self.from_employee(record, requirements:, documents:)
      valid_documents = documents.select { |document| document.complete? && !document.expired? }
      missing_titles = requirements.filter_map do |requirement|
        requirement.fetch(:title) unless valid_documents.any? { |document| document.title == requirement.fetch(:title) }
      end
      attention_count = documents.count(&:attention_needed?)
      complete_count = requirements.count do |requirement|
        valid_documents.any? { |document| document.title == requirement.fetch(:title) }
      end

      new(
        employee_id: record.id,
        employee_name: record.full_name,
        department_name: record.department&.name,
        location_name: record.work_location&.name,
        coverage_percent: coverage_percent(complete_count, requirements.count),
        required_count: requirements.count,
        complete_count:,
        attention_count: attention_count + missing_titles.count,
        missing_titles:,
        status: status_for(missing_titles, documents)
      )
    end

    def complete?
      status == "ready"
    end

    def self.coverage_percent(complete_count, required_count)
      return 100 if required_count.zero?

      ((complete_count.to_f / required_count) * 100).round
    end

    def self.status_for(missing_titles, documents)
      return "blocked" if missing_titles.any? || documents.any?(&:expired?)
      return "needs_review" if documents.any?(&:attention_needed?)

      "ready"
    end

    private_class_method :coverage_percent, :status_for
  end
end
