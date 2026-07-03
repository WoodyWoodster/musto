module OpenEnrollment
  CampaignDto = Data.define(:id, :name, :plan_year, :starts_on, :ends_on, :status, :launched_at, :reminders_sent_at, :invitation_count) do
    def self.from_record(record)
      return unless record

      new(
        id: record.id,
        name: record.name,
        plan_year: record.plan_year,
        starts_on: record.starts_on,
        ends_on: record.ends_on,
        status: record.status,
        launched_at: record.launched_at,
        reminders_sent_at: record.reminders_sent_at,
        invitation_count: record.open_enrollment_invitations.size
      )
    end

    def active?
      status == "active"
    end
  end
end
