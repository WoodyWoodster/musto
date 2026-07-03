module Compensation
  ChangeCenterDto = Data.define(
    :employer,
    :metrics,
    :changes,
    :reviewable_changes,
    :approved_changes,
    :applied_changes,
    :packet,
    :packet_lines,
    :packet_holdbacks,
    :payroll_run
  ) do
    def generated?
      packet.present?
    end
  end
end
