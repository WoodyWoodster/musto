module Vitable
  RemoteCareGroupResponseDto = Data.define(
    :group_id,
    :external_reference_id,
    :name,
    :organization_id,
    :raw_payload
  ) do
    def self.from_hash(payload)
      attributes = payload.to_h.stringify_keys
      data = attributes.fetch("data", attributes)
      data = data.fetch("group", data) if data.respond_to?(:fetch)
      data = data.respond_to?(:to_h) ? data.to_h.stringify_keys : {}

      new(
        group_id: data.fetch("id", nil),
        external_reference_id: data.fetch("external_reference_id", nil),
        name: data.fetch("name", nil),
        organization_id: data.fetch("organization_id", nil),
        raw_payload: data
      )
    end

    def validate!(expected_group_id:, expected_external_reference_id:)
      raise ArgumentError, "Vitable care group response did not include a remote group ID" if group_id.blank?
      if expected_group_id.present? && group_id != expected_group_id
        raise ArgumentError, "Vitable care group response returned remote group ID #{group_id}, expected #{expected_group_id}"
      end

      if expected_external_reference_id.present? && external_reference_id.blank?
        raise ArgumentError, "Vitable care group response did not include external_reference_id"
      end
      if expected_external_reference_id.present? && external_reference_id != expected_external_reference_id
        raise ArgumentError, "Vitable care group response returned external_reference_id #{external_reference_id}, expected #{expected_external_reference_id}"
      end

      self
    end
  end
end
