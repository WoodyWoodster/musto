module Benefits
  OffboardingCenterDto = Data.define(:employer, :metrics, :events, :coverage_lines, :issues, :packet, :packet_lines, :packet_holdbacks) do
    def ready_events
      events.select(&:ready?)
    end

    def ready_coverage_lines
      coverage_lines.select(&:ready?)
    end
  end
end
