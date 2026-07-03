module Benefits
  DependentVerificationCenterDto = Data.define(:employer, :metrics, :dependents, :verifications, :issues, :packet, :packet_lines, :packet_holdbacks) do
    def reviewable_verifications
      verifications.select(&:reviewable?)
    end

    def ready_dependents
      dependents.select(&:ready?)
    end
  end
end
