module Taxes
  AgencyAccountDto = Data.define(
    :key,
    :agency_name,
    :jurisdiction,
    :account_reference,
    :deposit_schedule,
    :next_due_on,
    :liability_cents,
    :status,
    :detail
  )
end
