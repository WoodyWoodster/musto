module Company
  PayrollSettingDto = Data.define(:key, :label, :value, :status) do
    def present?
      value.present?
    end
  end
end
