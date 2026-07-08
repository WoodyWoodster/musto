module Vitable
  RemoteCareMemberSyncResponseDto = Data.define(
    :request_id,
    :group_id,
    :accepted_at,
    :completed_at,
    :results,
    :raw_payload
  ) do
    def self.from_hash(payload)
      attributes = payload.to_h.stringify_keys
      data = attributes.fetch("data", attributes)
      data = data.respond_to?(:to_h) ? data.to_h.stringify_keys : {}

      new(
        request_id: data.fetch("request_id", nil),
        group_id: data.fetch("group_id", nil),
        accepted_at: data.fetch("accepted_at", nil),
        completed_at: data.fetch("completed_at", nil),
        results: data.fetch("results", nil),
        raw_payload: data
      )
    end

    def validate_submit!(expected_group_id:)
      validate_presence!("Vitable care member sync response")
      validate_group!("Vitable care member sync response", expected_group_id)
      self
    end

    def validate_refresh!(expected_group_id:, expected_request_id:)
      validate_presence!("Vitable care member sync refresh response")
      validate_group!("Vitable care member sync refresh response", expected_group_id)
      if expected_request_id.present? && request_id != expected_request_id
        raise ArgumentError, "Vitable care member sync refresh response returned remote request ID #{request_id}, expected #{expected_request_id}"
      end

      self
    end

    def to_request_state(refreshed_at:)
      {
        "request_id" => request_id,
        "group_id" => group_id,
        "accepted_at" => accepted_at,
        "completed_at" => completed_at,
        "results" => results,
        "status" => completed_at.present? ? "complete" : "processing",
        "refreshed_at" => refreshed_at.iso8601
      }.compact
    end

    private

    def validate_presence!(label)
      raise ArgumentError, "#{label} did not include a remote request ID" if request_id.blank?
      raise ArgumentError, "#{label} did not include a remote group ID" if group_id.blank?
      raise ArgumentError, "#{label} did not include accepted_at" if accepted_at.blank?
    end

    def validate_group!(label, expected_group_id)
      return if expected_group_id.blank? || group_id == expected_group_id

      raise ArgumentError, "#{label} returned remote group ID #{group_id}, expected #{expected_group_id}"
    end
  end
end
