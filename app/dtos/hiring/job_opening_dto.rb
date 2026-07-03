module Hiring
  JobOpeningDto = Data.define(:id, :title, :code, :department_name, :location_name, :status, :employment_type, :headcount, :compensation_min_cents, :compensation_max_cents, :remote, :target_start_on, :candidate_count, :active_candidate_count, :accepted_candidate_count) do
    def self.from_record(record)
      candidates = record.candidates

      new(
        id: record.id,
        title: record.title,
        code: record.code,
        department_name: record.department&.name,
        location_name: record.work_location&.name,
        status: record.status,
        employment_type: record.employment_type,
        headcount: record.headcount,
        compensation_min_cents: record.compensation_min_cents,
        compensation_max_cents: record.compensation_max_cents,
        remote: record.remote?,
        target_start_on: record.target_start_on,
        candidate_count: candidates.size,
        active_candidate_count: candidates.count { |candidate| !candidate.inactive? },
        accepted_candidate_count: candidates.count(&:accepted?)
      )
    end
  end
end
