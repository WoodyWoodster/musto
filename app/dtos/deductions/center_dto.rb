module Deductions
  CenterDto = Data.define(:employer, :payroll_run, :metrics, :deductions, :issues, :packets, :packet_lines, :packet_holdbacks, :packet_payload) do
    def latest_packet
      packets.first
    end

    def active_deductions
      deductions.select(&:active?)
    end

    def approvable_deductions
      deductions.select(&:approvable?)
    end

    def pausable_deductions
      deductions.select(&:pausable?)
    end
  end
end
