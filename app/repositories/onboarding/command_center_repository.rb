module Onboarding
  class CommandCenterRepository < ApplicationRepository
    def initialize(employer: nil)
      @employer = employer
    end

    def employees
      return Employee.none unless @employer

      @employer
        .employees
        .active
        .includes(:department, :work_location, :enrollments, :payroll_deductions, :onboarding_tasks, :employee_documents)
        .order(:last_name, :first_name)
    end

    def tasks
      return OnboardingTask.none unless @employer

      OnboardingTask
        .joins(:employee)
        .where(employees: { employer_id: @employer.id })
        .includes(employee: [ :department, :work_location ])
        .order(:due_on, :title)
    end

    def documents
      return EmployeeDocument.none unless @employer

      EmployeeDocument
        .joins(:employee)
        .where(employees: { employer_id: @employer.id })
        .includes(:employee)
        .order(document_priority, :expires_on, :title)
    end

    def find_document(id)
      EmployeeDocument.includes(employee: [ :onboarding_tasks, :employee_documents ]).find(id)
    end

    def verify_document(document)
      document.update!(
        status: "complete",
        issued_on: document.issued_on || Date.current,
        metadata: verification_metadata(document)
      )
      refresh_employee_status(document.employee)
      document
    end

    private

    def document_priority
      Arel.sql("CASE employee_documents.status WHEN 'expired' THEN 0 WHEN 'pending' THEN 1 ELSE 2 END")
    end

    def verification_metadata(document)
      document.metadata.to_h.merge(
        "verified_at" => Time.current.iso8601,
        "verified_by" => "ops_console"
      )
    end

    def refresh_employee_status(employee)
      open_work = employee.onboarding_tasks.open.exists? || employee.employee_documents.attention_needed.exists?
      employee.update!(onboarding_status: open_work ? "in_progress" : "complete")
    end
  end
end
