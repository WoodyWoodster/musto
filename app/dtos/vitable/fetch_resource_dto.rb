module Vitable
  FetchResourceDto = Data.define(:connection_id, :resource_type, :resource_id) do
    def self.from_event(connection:, event:)
      new(
        connection_id: connection.id,
        resource_type: event.resource_type,
        resource_id: event.resource_id
      )
    end
  end
end
