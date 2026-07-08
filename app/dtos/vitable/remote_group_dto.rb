module Vitable
  RemoteGroupDto = Data.define(
    :group_id,
    :external_reference_id,
    :name,
    :organization_id,
    :created_at,
    :updated_at,
    :raw_payload
  ) do
    def self.from_hash(payload)
      attributes = payload.respond_to?(:to_h) ? payload.to_h.stringify_keys : {}
      data = attributes.fetch("data", attributes)
      data = data.fetch("group", data) if data.respond_to?(:fetch)
      data = data.respond_to?(:to_h) ? data.to_h.stringify_keys : {}

      new(
        group_id: first_present(data["id"], data["group_id"]),
        external_reference_id: first_present(data["external_reference_id"], data["reference_id"]),
        name: data["name"],
        organization_id: first_present(data["organization_id"], data["organization_external_id"]),
        created_at: data["created_at"],
        updated_at: data["updated_at"],
        raw_payload: data
      )
    end

    def validate_identity!(response_label:)
      reference = external_reference_id.presence || name.presence || "unknown group"
      raise ArgumentError, "#{response_label} #{reference} did not include a remote group ID" if group_id.blank?

      self
    end

    def validate_care_group_response!(expected_group_id:, expected_external_reference_id:)
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

    def settings_metadata(source:, refreshed_at:, matched_by: nil)
      {
        "vitable_care_group_remote_reference_id" => external_reference_id,
        "vitable_care_group_last_refreshed_at" => refreshed_at,
        "vitable_care_group_snapshot_source" => source,
        "vitable_care_group_snapshot_matched_by" => matched_by,
        RemoteGroupSnapshotRepository::SNAPSHOT_KEY => snapshot(matched_by:, source:, refreshed_at:)
      }.compact
    end

    def snapshot(matched_by: nil, source: nil, refreshed_at: nil)
      summary.merge(
        "matched_by" => matched_by,
        "source" => source,
        "refreshed_at" => refreshed_at
      ).compact
    end

    def summary
      {
        "id" => group_id,
        "organization_id" => organization_id,
        "name" => name,
        "external_reference_id" => external_reference_id,
        "created_at" => created_at,
        "updated_at" => updated_at
      }.compact
    end

    def self.first_present(*values)
      values.compact_blank.first
    end

    private_class_method :first_present
  end
end
