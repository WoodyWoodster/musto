module WorkersComp
  CenterDto = Data.define(
    :employer,
    :policy,
    :metrics,
    :exposures,
    :claims,
    :issues,
    :packet,
    :packet_lines,
    :packet_claims,
    :packet_holdbacks,
    :packet_payload
  ) do
    def latest_packet
      packet
    end

    def open_claims
      claims.select(&:open?)
    end

    def closable_claims
      claims.select(&:closable?)
    end
  end
end
