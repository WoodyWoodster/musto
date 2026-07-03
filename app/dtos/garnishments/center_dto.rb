module Garnishments
  CenterDto = Data.define(
    :employer,
    :payroll_run,
    :metrics,
    :orders,
    :issues,
    :packet,
    :packet_lines,
    :packet_holdbacks,
    :agency_summaries,
    :packet_payload
  ) do
    def active_orders
      orders.select(&:active?)
    end

    def approvable_orders
      orders.select(&:approvable?)
    end

    def ready_orders
      orders.select(&:ready?)
    end

    def latest_packet
      packet
    end
  end
end
