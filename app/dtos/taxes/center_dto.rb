module Taxes
  CenterDto = Data.define(
    :employer,
    :metrics,
    :agency_accounts,
    :filing_calendar,
    :liabilities,
    :jurisdictions,
    :recommendations,
    :packets,
    :packet_payload
  ) do
    def generated?
      packet_payload.present?
    end

    def latest_packet
      packets.first
    end
  end
end
