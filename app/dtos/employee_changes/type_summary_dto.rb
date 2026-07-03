module EmployeeChanges
  TypeSummaryDto = Data.define(:request_type, :label, :request_count, :submitted_count, :applied_count, :status, :accent)
end
