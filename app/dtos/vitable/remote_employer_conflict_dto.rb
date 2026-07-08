module Vitable
  RemoteEmployerConflictDto = Data.define(
    :local_employer_id,
    :local_employer_vitable_id,
    :remote_employer_id,
    :remote_reference_id,
    :remote_name,
    :remote_legal_name,
    :matched_by,
    :source,
    :refreshed_at
  ) do
    def self.from_remote(employer:, remote_employer:, matched_by:, source:, refreshed_at:)
      remote = remote_employer.to_h.stringify_keys

      new(
        local_employer_id: employer.id,
        local_employer_vitable_id: employer.vitable_id,
        remote_employer_id: remote.fetch("id", nil),
        remote_reference_id: remote.fetch("reference_id", nil).presence || remote.fetch("external_reference_id", nil),
        remote_name: remote.fetch("name", nil),
        remote_legal_name: remote.fetch("legal_name", nil),
        matched_by:,
        source:,
        refreshed_at:
      )
    end

    def to_metadata
      {
        "local_employer_id" => local_employer_id,
        "local_employer_vitable_id" => local_employer_vitable_id,
        "remote_employer_id" => remote_employer_id,
        "remote_reference_id" => remote_reference_id,
        "remote_name" => remote_name,
        "remote_legal_name" => remote_legal_name,
        "matched_by" => matched_by,
        "source" => source,
        "refreshed_at" => refreshed_at
      }.compact
    end
  end
end
