module Documents
  DocumentDto = Data.define(
    :id,
    :employee_id,
    :employee_name,
    :department_name,
    :location_name,
    :title,
    :document_type,
    :status,
    :attention_status,
    :issued_on,
    :expires_on,
    :requested_at,
    :verified_at,
    :source,
    :metadata
  ) do
    def self.from_record(record)
      new(
        id: record.id,
        employee_id: record.employee_id,
        employee_name: record.employee.full_name,
        department_name: record.employee.department&.name,
        location_name: record.employee.work_location&.name,
        title: record.title,
        document_type: record.document_type,
        status: record.status,
        attention_status: attention_status_for(record),
        issued_on: record.issued_on,
        expires_on: record.expires_on,
        requested_at: record.requested_at,
        verified_at: record.verified_at,
        source: record.source,
        metadata: record.metadata.to_h
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

    def requested?
      status == "requested"
    end

    def self.attention_status_for(record)
      return "expired" if record.status == "expired" || record.expired?
      return "needs_review" if record.status.in?([ "pending", "requested" ])
      return "needs_review" if record.expiring_soon?

      "ready"
    end

    private_class_method :attention_status_for
  end
end
