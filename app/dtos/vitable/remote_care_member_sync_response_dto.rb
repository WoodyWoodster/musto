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
      validate_results!("Vitable care member sync refresh response")

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

    def validate_results!(label)
      if completed_at.present? && results.blank?
        raise ArgumentError, "#{label} completed without results"
      end
      return if results.blank?

      unless results.respond_to?(:to_h)
        raise ArgumentError, "#{label} results must be an object"
      end

      result_hash = results.to_h.stringify_keys
      validate_result_array!(label, result_hash, "added_group_member_ids")
      validate_result_array!(label, result_hash, "removed_group_member_ids")
      validate_result_array!(label, result_hash, "failures")
      result_hash.fetch("failures").each_with_index do |failure, index|
        validate_failure!(label, failure, index)
      end
    end

    def validate_result_array!(label, result_hash, key)
      value = result_hash.fetch(key, nil)
      raise ArgumentError, "#{label} results did not include #{key}" unless value.is_a?(Array)
    end

    def validate_failure!(label, failure, index)
      unless failure.respond_to?(:to_h)
        raise ArgumentError, "#{label} failure #{index + 1} must be an object"
      end

      failure = failure.to_h.stringify_keys
      missing_fields = %w[operation reference_id reason].filter_map do |key|
        key if failure.fetch(key, nil).blank?
      end
      if missing_fields.any?
        raise ArgumentError, "#{label} failure #{index + 1} did not include #{missing_fields.to_sentence}"
      end
      return if failure.fetch("operation").to_s.in?(%w[add remove])

      raise ArgumentError, "#{label} failure #{index + 1} returned unsupported operation #{failure.fetch("operation")}"
    end
  end
end
