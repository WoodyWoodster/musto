module Documents
  RequirementDto = Data.define(
    :key,
    :title,
    :document_type,
    :owner,
    :cadence,
    :blocking_surface,
    :coverage_count,
    :missing_count,
    :expiring_count,
    :status
  ) do
    def self.from_definition(definition, employees:, documents_by_employee:)
      employee_documents = employees.map { |employee| documents_by_employee.fetch(employee.id, []) }
      complete_count = employee_documents.count do |documents|
        documents.any? { |document| document.title == definition.fetch(:title) && document.complete? && !document.expired? }
      end
      expiring_count = employee_documents.sum do |documents|
        documents.count { |document| document.title == definition.fetch(:title) && document.expiring_soon? }
      end
      missing_count = employees.count - complete_count

      new(
        key: definition.fetch(:key),
        title: definition.fetch(:title),
        document_type: definition.fetch(:document_type),
        owner: definition.fetch(:owner),
        cadence: definition.fetch(:cadence),
        blocking_surface: definition.fetch(:blocking_surface),
        coverage_count: complete_count,
        missing_count:,
        expiring_count:,
        status: status_for(missing_count, expiring_count)
      )
    end

    def self.status_for(missing_count, expiring_count)
      return "blocked" if missing_count.positive?
      return "needs_review" if expiring_count.positive?

      "ready"
    end

    private_class_method :status_for
  end
end
