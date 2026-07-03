module Compensation
  CenterDto = Data.define(
    :employer,
    :metrics,
    :employees,
    :departments,
    :adjustments,
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
