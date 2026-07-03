module Vitable
  EndpointCoverageDto = Data.define(:resource_type, :fetch_path, :events_count, :status, :last_seen_at)
end
