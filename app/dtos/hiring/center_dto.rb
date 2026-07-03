module Hiring
  CenterDto = Data.define(
    :employer,
    :metrics,
    :job_openings,
    :candidates,
    :pipeline_stages,
    :issues,
    :handoff_batches,
    :handoff_lines,
    :handoff_holdbacks,
    :handoff_payload
  ) do
    def latest_handoff_batch
      handoff_batches.first
    end

    def offerable_candidates
      candidates.select(&:offerable?)
    end

    def accepted_candidates
      candidates.select(&:accepted?)
    end
  end
end
