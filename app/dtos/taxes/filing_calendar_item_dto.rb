module Taxes
  FilingCalendarItemDto = Data.define(
    :key,
    :title,
    :agency_name,
    :jurisdiction,
    :period_label,
    :due_on,
    :liability_cents,
    :deposit_schedule,
    :status
  )
end
