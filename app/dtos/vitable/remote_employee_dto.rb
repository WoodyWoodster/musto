module Vitable
  RemoteEmployeeDto = Data.define(
    :remote_employee_id,
    :reference_id,
    :email,
    :status,
    :member_id,
    :employee_class,
    :hire_date,
    :termination_date,
    :date_of_birth,
    :phone,
    :address,
    :deductions,
    :dependents,
    :raw_payload
  ) do
    def self.from_hash(payload)
      attributes = payload.respond_to?(:to_h) ? payload.to_h.stringify_keys : {}
      member = attributes.fetch("member", {})
      member = member.respond_to?(:to_h) ? member.to_h.stringify_keys : {}

      new(
        remote_employee_id: first_present(attributes["id"], attributes["employee_id"]),
        reference_id: first_present(attributes["reference_id"], attributes["external_reference_id"]),
        email: attributes["email"].to_s.presence,
        status: attributes["status"],
        member_id: first_present(attributes["member_id"], member["id"]),
        employee_class: first_present(attributes["employee_class"], attributes["class"], attributes["employment_class"]),
        hire_date: date_from(first_present(attributes["hire_date"], attributes["start_date"], attributes["start_on"])),
        termination_date: date_from(first_present(attributes["termination_date"], attributes["terminated_on"], attributes["end_date"])),
        date_of_birth: date_from(first_present(attributes["date_of_birth"], attributes["dob"])),
        phone: first_present(attributes["phone"], attributes["phone_number"]),
        address: address_from(attributes["address"]),
        deductions: Array(attributes.fetch("deductions", [])),
        dependents: Array(first_present(attributes["dependents"], member["dependents"])),
        raw_payload: attributes
      )
    end

    def validate_identity!(response_label:)
      reference = reference_id.presence || email.presence || "unknown remote employee"
      raise ArgumentError, "#{response_label} #{reference} did not include a remote employee ID" if remote_employee_id.blank?
      raise ArgumentError, "#{response_label} #{reference} did not include a remote member ID" if member_id.blank?

      self
    end

    def local_employment_status
      case status.to_s.downcase
      when "inactive", "deactivated", "terminated"
        "terminated"
      when "active", "reactivated"
        "active"
      end
    end

    def metadata(source:, refreshed_at:, census_sync_status: nil)
      {
        "vitable_census_sync_status" => census_sync_status,
        "vitable_remote_status" => status,
        "vitable_member_id" => member_id,
        "vitable_remote_reference_id" => reference_id,
        "vitable_remote_employee_class" => employee_class,
        "vitable_remote_hire_date" => hire_date&.iso8601,
        "vitable_remote_termination_date" => termination_date&.iso8601,
        "vitable_remote_date_of_birth" => date_of_birth&.iso8601,
        "vitable_remote_phone" => phone,
        "vitable_remote_address" => address,
        "vitable_remote_deductions" => deductions,
        "vitable_last_refreshed_at" => refreshed_at,
        "vitable_last_snapshot_source" => source,
        "vitable_last_resource_snapshot" => summary
      }.compact
    end

    def summary
      {
        "id" => remote_employee_id,
        "reference_id" => reference_id,
        "email" => email,
        "first_name" => raw_payload.fetch("first_name", nil),
        "last_name" => raw_payload.fetch("last_name", nil),
        "status" => status,
        "member_id" => member_id,
        "employee_class" => employee_class,
        "hire_date" => hire_date&.iso8601,
        "termination_date" => termination_date&.iso8601,
        "date_of_birth" => date_of_birth&.iso8601,
        "phone" => phone
      }.compact
    end

    def self.address_from(value)
      return unless value.respond_to?(:to_h)

      attributes = value.to_h.stringify_keys
      {
        "address_line_1" => first_present(attributes["address_line_1"], attributes["line1"], attributes["street1"]),
        "address_line_2" => first_present(attributes["address_line_2"], attributes["line2"], attributes["street2"]),
        "city" => attributes["city"],
        "state" => attributes["state"],
        "zipcode" => first_present(attributes["zipcode"], attributes["zip_code"], attributes["postal_code"])
      }.compact
    end

    def self.date_from(value)
      return value if value.is_a?(Date)
      return value.to_date if value.respond_to?(:to_date)
      return if value.blank?

      Date.iso8601(value.to_s)
    rescue ArgumentError
      nil
    end

    def self.first_present(*values)
      values.compact_blank.first
    end

    private_class_method :address_from, :date_from, :first_present
  end
end
