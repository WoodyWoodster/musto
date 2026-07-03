module YearEnd
  CenterDto = Data.define(
    :employer,
    :tax_year,
    :metrics,
    :forms,
    :issues,
    :packet,
    :packet_lines,
    :packet_holdbacks,
    :packet_payload
  ) do
    def generated?
      packet_payload.present?
    end

    def deliverable_forms
      forms.select(&:deliverable)
    end

    def correction_forms
      forms.select(&:correction_needed)
    end
  end
end
