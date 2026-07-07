module Vitable
  RefreshApiSnapshotDto = Data.define(:connection_id, :requested_by) do
    def self.from_params(params)
      attributes = ApplicationDto.coerce_hash(params)

      new(
        connection_id: ApplicationDto.id_from(params),
        requested_by: attributes.fetch("requested_by", "ops_console")
      )
    end
  end
end
