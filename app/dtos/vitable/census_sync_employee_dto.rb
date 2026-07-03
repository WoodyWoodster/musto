module Vitable
  CensusSyncEmployeeDto = Data.define(
    :employee_id,
    :employee_name,
    :email,
    :phone,
    :date_of_birth,
    :start_date,
    :department_name,
    :location_name,
    :pay_type,
    :compensation_type,
    :employee_class,
    :reference_id,
    :remote_employee_id,
    :enrollment_count,
    :status,
    :readiness_status,
    :readiness_reason
  ) do
    def self.from_hash(payload)
      attributes = payload.to_h.stringify_keys

      new(
        employee_id: attributes.fetch("employee_id"),
        employee_name: attributes.fetch("employee_name"),
        email: attributes.fetch("email"),
        phone: attributes.fetch("phone"),
        date_of_birth: Date.iso8601(attributes.fetch("date_of_birth")),
        start_date: attributes["start_date"].present? ? Date.iso8601(attributes.fetch("start_date")) : nil,
        department_name: attributes.fetch("department_name"),
        location_name: attributes.fetch("location_name"),
        pay_type: attributes.fetch("pay_type"),
        compensation_type: attributes.fetch("compensation_type"),
        employee_class: attributes.fetch("employee_class"),
        reference_id: attributes.fetch("reference_id"),
        remote_employee_id: attributes.fetch("remote_employee_id", nil),
        enrollment_count: attributes.fetch("enrollment_count", 0),
        status: attributes.fetch("status"),
        readiness_status: attributes.fetch("readiness_status"),
        readiness_reason: attributes.fetch("readiness_reason")
      )
    end

    def remote_pending?
      remote_employee_id.blank?
    end
  end
end
