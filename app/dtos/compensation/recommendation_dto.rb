module Compensation
  RecommendationDto = Data.define(:key, :title, :detail, :severity, :status, :owner, :action_path)
end
