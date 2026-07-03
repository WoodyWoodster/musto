module Training
  CenterDto = Data.define(:employer, :metrics, :programs, :assignments, :issues, :audit_packets, :audit_lines, :audit_holdbacks, :audit_payload) do
    def current_program
      programs.find { |program| program.status.in?(%w[active draft]) } || programs.first
    end

    def latest_packet
      audit_packets.first
    end

    def completable_assignments
      assignments.select(&:completable?)
    end

    def certificate_ready_assignments
      assignments.select { |assignment| assignment.readiness_status == "certificate_ready" }
    end
  end
end
