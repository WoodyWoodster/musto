module Documents
  class DocumentRepository < ApplicationRepository
    REQUIRED_DOCUMENTS = [
      {
        key: "form_i9",
        title: "Form I-9",
        document_type: "identity",
        owner: "People",
        cadence: "At hire",
        blocking_surface: "Payroll and federal work authorization",
        expires_on: nil
      },
      {
        key: "form_w4",
        title: "W-4",
        document_type: "tax",
        owner: "Payroll",
        cadence: "At hire or tax change",
        blocking_surface: "Payroll withholding",
        expires_on: nil
      },
      {
        key: "direct_deposit_authorization",
        title: "Direct deposit authorization",
        document_type: "payroll",
        owner: "Payroll",
        cadence: "Before first payroll",
        blocking_surface: "Payroll funding",
        expires_on: nil
      },
      {
        key: "benefits_disclosure",
        title: "Benefits disclosure",
        document_type: "benefits",
        owner: "Benefits",
        cadence: "Annual",
        blocking_surface: "Vitable enrollment",
        expires_on: -> { Date.current.end_of_year }
      },
      {
        key: "handbook_acknowledgment",
        title: "Handbook acknowledgment",
        document_type: "policy",
        owner: "People",
        cadence: "Annual",
        blocking_surface: "Compliance policy attestation",
        expires_on: -> { Date.current.end_of_year }
      }
    ].freeze

    def initialize(employer: nil)
      @employer = employer
    end

    def required_documents
      REQUIRED_DOCUMENTS
    end

    def employees
      return Employee.none unless @employer

      @employer
        .employees
        .active
        .includes(:department, :work_location, :employee_documents)
        .order(:last_name, :first_name)
    end

    def documents
      return EmployeeDocument.none unless @employer

      EmployeeDocument
        .joins(:employee)
        .where(employees: { employer_id: @employer.id })
        .includes(employee: [ :department, :work_location ])
        .order(document_priority, Employee.arel_table[:last_name].asc, Employee.arel_table[:first_name].asc, :title)
    end

    def batches
      payload = @employer&.settings.to_h.fetch("document_request_batch", nil)
      payload.present? ? [ payload ] : []
    end

    def find_document(id)
      EmployeeDocument.includes(employee: [ :onboarding_tasks, :employee_documents ]).find(id)
    end

    def verify_document(document, reviewed_by:)
      timestamp = Time.current

      document.update!(
        status: "complete",
        issued_on: document.issued_on || Date.current,
        verified_at: timestamp,
        metadata: verification_metadata(document, reviewed_by:, timestamp:)
      )
      refresh_employee_status(document.employee)
      document
    end

    def generate_request_batch(requested_by:)
      requests = []
      holdbacks = []
      timestamp = Time.current

      employees.each do |employee|
        employee_documents = employee.employee_documents.to_a

        required_documents.each do |requirement|
          document = employee_documents.find { |record| record.title == requirement.fetch(:title) }

          if document_present?(document)
            holdbacks << holdback_line(employee, requirement, document)
          else
            document ||= employee.employee_documents.build(title: requirement.fetch(:title))
            document.assign_attributes(request_attributes(requirement, requested_by:, timestamp:))
            document.save!
            employee_documents << document unless employee_documents.include?(document)
            requests << request_line(document)
          end
        end
      end

      batch = batch_payload(requests, holdbacks, requested_by:, timestamp:)
      @employer.update!(settings: @employer.settings.to_h.merge("document_request_batch" => batch))
      batch
    end

    private

    def document_priority
      Arel.sql("CASE employee_documents.status WHEN 'expired' THEN 0 WHEN 'pending' THEN 1 WHEN 'requested' THEN 2 ELSE 3 END")
    end

    def request_attributes(requirement, requested_by:, timestamp:)
      {
        document_type: requirement.fetch(:document_type),
        status: "requested",
        issued_on: nil,
        requested_at: timestamp,
        source: "ops_console",
        expires_on: requirement_expiry(requirement),
        metadata: {
          "requested_by" => requested_by,
          "requested_at" => timestamp.iso8601,
          "requirement_key" => requirement.fetch(:key),
          "blocking_surface" => requirement.fetch(:blocking_surface)
        }
      }
    end

    def requirement_expiry(requirement)
      value = requirement.fetch(:expires_on)
      value.respond_to?(:call) ? value.call : value
    end

    def document_present?(document)
      document.present? && document.complete? && !document.expired? && !document.expiring_soon?
    end

    def verification_metadata(document, reviewed_by:, timestamp:)
      document.metadata.to_h.merge(
        "verified_at" => timestamp.iso8601,
        "verified_by" => reviewed_by,
        "verification_source" => "document_vault"
      )
    end

    def refresh_employee_status(employee)
      open_work = employee.onboarding_tasks.open.exists? || employee.employee_documents.attention_needed.exists?
      employee.update!(onboarding_status: open_work ? "in_progress" : "complete")
    end

    def batch_payload(requests, holdbacks, requested_by:, timestamp:)
      {
        "batch_id" => "document_requests_#{@employer.id}_#{timestamp.to_i}",
        "generated_at" => timestamp.iso8601,
        "requested_by" => requested_by,
        "employer_id" => @employer.id,
        "status" => requests.any? ? "needs_review" : "ready",
        "totals" => {
          "request_count" => requests.count,
          "employee_count" => requests.map { |line| line.fetch("employee_id") }.uniq.count,
          "holdback_count" => holdbacks.count
        },
        "requests" => requests,
        "holdbacks" => holdbacks
      }
    end

    def request_line(document)
      {
        "employee_id" => document.employee_id,
        "employee_name" => document.employee.full_name,
        "document_id" => document.id,
        "title" => document.title,
        "document_type" => document.document_type,
        "status" => document.status,
        "requested_at" => document.requested_at.iso8601
      }
    end

    def holdback_line(employee, requirement, document)
      {
        "employee_id" => employee.id,
        "employee_name" => employee.full_name,
        "title" => requirement.fetch(:title),
        "reason" => "#{document.status.humanize} document already satisfies the #{requirement.fetch(:cadence).downcase} requirement",
        "status" => "ready"
      }
    end
  end
end
