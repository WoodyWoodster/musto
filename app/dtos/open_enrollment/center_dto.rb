module OpenEnrollment
  CenterDto = Data.define(
    :employer,
    :campaign,
    :metrics,
    :plans,
    :invitations,
    :issues,
    :batches,
    :batch_lines,
    :batch_holdbacks,
    :batch_payload
  ) do
    def latest_batch
      batches.first
    end

    def active_campaign?
      campaign&.active?
    end

    def pending_invitations
      invitations.reject(&:complete?)
    end

    def remindable_invitations
      invitations.select(&:remindable?)
    end
  end
end
