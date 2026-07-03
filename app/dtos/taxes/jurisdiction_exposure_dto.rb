module Taxes
  JurisdictionExposureDto = Data.define(
    :jurisdiction,
    :location_name,
    :employee_count,
    :annual_payroll_cents,
    :current_run_payroll_cents,
    :remote,
    :registration_status,
    :status
  )
end
