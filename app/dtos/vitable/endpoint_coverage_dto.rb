module Vitable
  EndpointCoverageDto = Data.define(:resource_type, :fetch_path, :operation, :method, :activity_count, :status, :last_seen_at) do
    def events_count
      activity_count
    end
  end
end
