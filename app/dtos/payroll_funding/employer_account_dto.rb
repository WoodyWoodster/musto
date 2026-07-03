module PayrollFunding
  EmployerAccountDto = Data.define(:id, :name, :institution_name, :account_type, :routing_number_last4, :account_last4, :status, :verification_method, :primary_account, :verified_at) do
    def self.from_record(record)
      new(
        id: record.id,
        name: record.name,
        institution_name: record.institution_name,
        account_type: record.account_type,
        routing_number_last4: record.routing_number_last4,
        account_last4: record.account_last4,
        status: record.status,
        verification_method: record.verification_method,
        primary_account: record.primary_account?,
        verified_at: record.verified_at
      )
    end

    def ready_for_funding?
      status == "verified"
    end
  end
end
