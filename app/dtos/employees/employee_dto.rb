module Employees
  EmployeeDto = Data.define(:employer_id, :first_name, :last_name, :email, :date_of_birth, :employment_status, :metadata) do
    def self.from_params(params)
      attrs = ApplicationDto.coerce_hash(params).symbolize_keys

      new(
        employer_id: attrs.fetch(:employer_id),
        first_name: attrs.fetch(:first_name),
        last_name: attrs.fetch(:last_name),
        email: attrs.fetch(:email),
        date_of_birth: attrs[:date_of_birth],
        employment_status: attrs[:employment_status].presence || "active",
        metadata: attrs[:metadata] || {}
      )
    end

    def to_attributes
      {
        employer_id:,
        first_name:,
        last_name:,
        email:,
        date_of_birth:,
        employment_status:,
        metadata:
      }
    end
  end
end
