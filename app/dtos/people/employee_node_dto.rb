module People
  EmployeeNodeDto = Data.define(
    :employee_id,
    :employee_name,
    :email,
    :title,
    :department_name,
    :location_name,
    :manager_id,
    :manager_name,
    :direct_report_count,
    :remote_employee_id,
    :status,
    :status_reason
  ) do
    def self.from_record(record, direct_report_count:)
      new(
        employee_id: record.id,
        employee_name: record.full_name,
        email: record.email,
        title: record.title,
        department_name: record.department&.name || "Unassigned",
        location_name: record.work_location&.name || "Unassigned",
        manager_id: record.manager_id,
        manager_name: record.manager&.full_name,
        direct_report_count:,
        remote_employee_id: record.vitable_id,
        status: status_for(record, direct_report_count),
        status_reason: reason_for(record, direct_report_count)
      )
    end

    def manager?
      direct_report_count.positive?
    end

    def unassigned?
      manager_id.blank? && direct_report_count.zero?
    end

    private_class_method def self.status_for(record, direct_report_count)
      return "ready" if record.manager_id.present? || direct_report_count.positive?

      "needs_review"
    end

    private_class_method def self.reason_for(record, direct_report_count)
      return "#{direct_report_count} direct reports" if direct_report_count.positive?
      return "Reports to #{record.manager.full_name}" if record.manager

      "Manager assignment needed"
    end
  end
end
