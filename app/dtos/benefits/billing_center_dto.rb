module Benefits
  BillingCenterDto = Data.define(
    :employer,
    :metrics,
    :invoices,
    :lines,
    :variances,
    :packets,
    :packet_lines,
    :packet_holdbacks,
    :packet_payload
  ) do
    def latest_invoice
      invoices.first
    end

    def latest_packet
      packets.first
    end

    def open_invoices
      invoices.reject(&:paid?)
    end

    def blocked_lines
      lines.select(&:blocked?)
    end
  end
end
