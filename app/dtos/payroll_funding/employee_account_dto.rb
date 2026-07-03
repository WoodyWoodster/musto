module PayrollFunding
  EmployeeAccountDto = Data.define(
    :id,
    :employee_id,
    :employee_name,
    :department_name,
    :location_name,
    :nickname,
    :institution_name,
    :account_type,
    :routing_number_last4,
    :account_last4,
    :allocation_type,
    :allocation_value,
    :status,
    :verification_method,
    :primary_account,
    :verified_at,
    :prenote_sent_at,
    :readiness_status
  ) do
    def self.from_record(record)
      employee = record.employee

      new(
        id: record.id,
        employee_id: record.employee_id,
        employee_name: employee.full_name,
        department_name: employee.department&.name || "Unassigned",
        location_name: employee.work_location&.name || "No location",
        nickname: record.nickname,
        institution_name: record.institution_name,
        account_type: record.account_type,
        routing_number_last4: record.routing_number_last4,
        account_last4: record.account_last4,
        allocation_type: record.allocation_type,
        allocation_value: record.allocation_value,
        status: record.status,
        verification_method: record.verification_method,
        primary_account: record.primary_account?,
        verified_at: record.verified_at,
        prenote_sent_at: record.prenote_sent_at,
        readiness_status: record.readiness_status
      )
    end

    def verified?
      status == "verified"
    end

    def reviewable?
      %w[pending_verification prenote_sent].include?(status)
    end
  end
end
