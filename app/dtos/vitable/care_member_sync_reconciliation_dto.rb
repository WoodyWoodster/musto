module Vitable
  CareMemberSyncReconciliationDto = Data.define(
    :status,
    :submitted_count,
    :succeeded_count,
    :failed_count,
    :added_group_member_ids,
    :removed_group_member_ids,
    :failure_reference_ids,
    :applied_employee_ids,
    :applied_enrollment_ids
  ) do
    def to_h
      {
        "status" => status,
        "submitted_count" => submitted_count,
        "succeeded_count" => succeeded_count,
        "failed_count" => failed_count,
        "added_group_member_ids" => added_group_member_ids,
        "removed_group_member_ids" => removed_group_member_ids,
        "failure_reference_ids" => failure_reference_ids,
        "applied_employee_ids" => applied_employee_ids,
        "applied_enrollment_ids" => applied_enrollment_ids
      }
    end
  end
end
