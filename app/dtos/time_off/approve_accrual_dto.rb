module TimeOff
  ApproveAccrualDto = Data.define(:accrual_id, :approved_by) do
    def self.from_params(params)
      attributes = ApplicationDto.coerce_hash(params)

      new(
        accrual_id: attributes.fetch(:id) { attributes.fetch("id") }.to_i,
        approved_by: attributes.fetch(:approved_by) { attributes.fetch("approved_by", "payroll_admin") }
      )
    end
  end
end
