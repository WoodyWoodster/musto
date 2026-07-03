module Hiring
  PipelineStageDto = Data.define(:stage, :label, :candidate_count, :top_candidate_name, :status)
end
