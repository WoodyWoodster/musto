module Documents
  class CenterQuery
    def initialize(employer_repository: Employers::EmployerRepository.new)
      @employer = employer_repository.first_for_operations
      @repository = DocumentRepository.new(employer: @employer)
    end

    def call
      records = @repository.documents.to_a
      employees = @repository.employees.to_a
      requirements = @repository.required_documents
      documents_by_employee = records.group_by(&:employee_id)
      batches = @repository.batches
      latest_batch = batches.first.to_h

      CenterDto.new(
        employer: Operations::EmployerContextDto.from_record(@employer),
        metrics: metrics(records, employees, requirements, latest_batch),
        documents: records.map { |record| DocumentDto.from_record(record) },
        employees: employees.map { |employee| EmployeeCoverageDto.from_employee(employee, requirements:, documents: documents_by_employee.fetch(employee.id, [])) },
        requirements: requirements.map { |requirement| RequirementDto.from_definition(requirement, employees:, documents_by_employee:) },
        exceptions: exceptions(records, employees, requirements, documents_by_employee),
        batches: batches.map { |payload| BatchDto.from_hash(payload) },
        batch_lines: latest_batch.fetch("requests", []).map { |payload| BatchLineDto.from_hash(payload) },
        batch_holdbacks: latest_batch.fetch("holdbacks", []).map { |payload| BatchHoldbackDto.from_hash(payload) },
        batch_payload: batches.first
      )
    end

    private

    def metrics(records, employees, requirements, latest_batch)
      complete_count = records.count { |record| record.complete? && !record.expired? }
      attention_count = records.count(&:attention_needed?)
      expiring_count = records.count(&:expiring_soon?)
      expected_count = employees.count * requirements.count
      coverage_percent = expected_count.zero? ? 100 : ((complete_count.to_f / expected_count) * 100).round
      latest_request_count = latest_batch.fetch("totals", {}).fetch("request_count", 0)

      [
        MetricDto.new(label: "Document coverage", value: coverage_percent, hint: "#{complete_count}/#{expected_count} required documents clear", status: coverage_percent == 100 ? "ready" : "needs_review", accent: "bg-emerald-500", format: "percent"),
        MetricDto.new(label: "Attention queue", value: attention_count, hint: "pending, requested, expired, or expiring", status: attention_count.positive? ? "needs_review" : "ready", accent: "bg-amber-500", format: "number"),
        MetricDto.new(label: "Expiring soon", value: expiring_count, hint: "documents inside the 60-day renewal window", status: expiring_count.positive? ? "needs_review" : "ready", accent: "bg-rose-500", format: "number"),
        MetricDto.new(label: "Latest requests", value: latest_request_count, hint: latest_batch.present? ? "most recent request batch" : "no request batch generated", status: latest_request_count.positive? ? "needs_review" : "ready", accent: "bg-sky-500", format: "number")
      ]
    end

    def exceptions(records, employees, requirements, documents_by_employee)
      routes = Rails.application.routes.url_helpers
      coverage = employees.map { |employee| EmployeeCoverageDto.from_employee(employee, requirements:, documents: documents_by_employee.fetch(employee.id, [])) }
      missing_employees = coverage.select { |employee| employee.status == "blocked" }
      expiring_documents = records.select(&:expiring_soon?)
      requested_documents = records.select(&:requested?)
      pending_documents = records.select(&:pending?)
      expired_documents = records.select { |record| record.status == "expired" || record.expired? }
      items = []

      if missing_employees.any?
        items << ExceptionDto.new(key: "missing_required_documents", title: "Collect missing required documents", detail: "#{missing_employees.count} employees are missing at least one required employment document.", severity: "high", status: "blocked", owner: "People", count: missing_employees.count, action_path: routes.documents_path)
      end

      if expired_documents.any?
        items << ExceptionDto.new(key: "expired_documents", title: "Renew expired documents", detail: "#{expired_documents.count} documents are expired and should be re-requested before payroll or benefits handoff.", severity: "critical", status: "blocked", owner: "Compliance", count: expired_documents.count, action_path: routes.documents_path)
      end

      if expiring_documents.any?
        items << ExceptionDto.new(key: "expiring_documents", title: "Renew documents before expiry", detail: "#{expiring_documents.count} documents are inside the 60-day renewal window.", severity: "medium", status: "needs_review", owner: "People", count: expiring_documents.count, action_path: routes.documents_path)
      end

      if requested_documents.any? || pending_documents.any?
        items << ExceptionDto.new(key: "open_requests", title: "Follow up on employee requests", detail: "#{requested_documents.count + pending_documents.count} documents are waiting on employee upload or operations review.", severity: "medium", status: "needs_review", owner: "People Ops", count: requested_documents.count + pending_documents.count, action_path: routes.documents_path)
      end

      return items if items.any?

      [
        ExceptionDto.new(key: "document_vault_ready", title: "Document vault is audit-ready", detail: "Required employment, tax, payroll, benefits, and policy documents are current.", severity: "low", status: "ready", owner: "People", count: records.count, action_path: routes.documents_path)
      ]
    end
  end
end
