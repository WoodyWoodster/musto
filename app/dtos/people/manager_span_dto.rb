module People
  ManagerSpanDto = Data.define(:manager_id, :manager_name, :title, :department_name, :direct_report_count, :status)
end
