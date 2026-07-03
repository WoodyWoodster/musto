module Taxes
  SubmitAgencyRegistrationDto = Data.define(:registration_id, :submitted_by, :confirmation_number) do
    def self.from_params(params)
      attributes = ApplicationDto.coerce_hash(params)

      new(
        registration_id: attributes.fetch(:id) { attributes.fetch("id") }.to_i,
        submitted_by: attributes.fetch("submitted_by", "payroll_admin"),
        confirmation_number: attributes.fetch("confirmation_number", nil)
      )
    end
  end
end
