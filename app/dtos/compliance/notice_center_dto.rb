module Compliance
  NoticeCenterDto = Data.define(
    :employer,
    :metrics,
    :notices,
    :issues,
    :packet,
    :packet_lines,
    :packet_holdbacks,
    :packet_payload
  ) do
    def generated?
      packet_payload.present?
    end

    def actionable_notices
      notices.select(&:actionable)
    end

    def resolved_notices
      notices.select(&:resolved)
    end
  end
end
