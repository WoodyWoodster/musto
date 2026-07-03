module TimeOff
  GenerateAccrualRunDto = Data.define(:period_start_on, :requested_by) do
    def self.from_params(params)
      attributes = ApplicationDto.coerce_hash(params)
      raw_period = attributes.fetch(:period_start_on) { attributes.fetch("period_start_on", Date.current.beginning_of_month.iso8601) }

      new(
        period_start_on: Date.iso8601(raw_period.to_s).beginning_of_month,
        requested_by: attributes.fetch(:requested_by) { attributes.fetch("requested_by", "payroll_admin") }
      )
    end
  end
end
