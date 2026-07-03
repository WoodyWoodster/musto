module Taxes
  AgencyRegistrationDto = Data.define(
    :id,
    :agency_name,
    :jurisdiction,
    :registration_type,
    :account_number,
    :deposit_schedule,
    :status,
    :risk_level,
    :due_on,
    :submitted_at,
    :confirmed_at,
    :confirmation_number,
    :next_deposit_due_on,
    :owner,
    :location_name,
    :remote,
    :notes,
    :submittable
  ) do
    def self.from_record(registration)
      new(
        id: registration.id,
        agency_name: registration.agency_name,
        jurisdiction: registration.jurisdiction,
        registration_type: registration.registration_type,
        account_number: registration.account_number,
        deposit_schedule: registration.deposit_schedule,
        status: registration.status,
        risk_level: registration.risk_level,
        due_on: registration.due_on,
        submitted_at: registration.submitted_at,
        confirmed_at: registration.confirmed_at,
        confirmation_number: registration.confirmation_number,
        next_deposit_due_on: registration.next_deposit_due_on,
        owner: registration.owner,
        location_name: registration.work_location&.name,
        remote: registration.work_location&.remote? || false,
        notes: registration.notes,
        submittable: registration.submittable?
      )
    end
  end
end
