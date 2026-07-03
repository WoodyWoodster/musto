module Taxes
  AgencyRegistrationCenterDto = Data.define(
    :employer,
    :metrics,
    :registrations,
    :issues,
    :packet,
    :packet_lines,
    :packet_holdbacks,
    :packet_payload
  ) do
    def generated?
      packet_payload.present?
    end

    def reviewable_registrations
      registrations.select(&:submittable)
    end

    def ready_registrations
      registrations.select { |registration| registration.status.in?(%w[submitted registered]) }
    end
  end
end
