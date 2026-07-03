module Onboarding
  DocumentDto = Data.define(
    :id,
    :employee_id,
    :employee_name,
    :title,
    :document_type,
    :status,
    :issued_on,
    :expires_on,
    :attention_status
  ) do
    def self.from_record(record)
      new(
        id: record.id,
        employee_id: record.employee_id,
        employee_name: record.employee.full_name,
        title: record.title,
        document_type: record.document_type,
        status: record.status,
        issued_on: record.issued_on,
        expires_on: record.expires_on,
        attention_status: attention_status_for(record)
      )
    end

    def complete?
      status == "complete"
    end

    def attention?
      attention_status != "ready"
    end

    def expired?
      attention_status == "expired"
    end

    def self.attention_status_for(record)
      return "expired" if record.status == "expired" || record.expired?
      return "needs_review" if record.status == "pending"
      return "needs_review" if expiring_soon?(record)

      "ready"
    end

    def self.expiring_soon?(record)
      record.expires_on.present? && record.expires_on <= 60.days.from_now.to_date
    end

    private_class_method :attention_status_for, :expiring_soon?
  end
end
