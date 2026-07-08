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
      attributes = payload.respond_to?(:to_h) ? payload.to_h.stringify_keys : {}
      data = resource_payload(attributes)
      group = nested_payload(data, "group")
      request_id = first_present(data["request_id"], data["id"], data["sync_request_id"])
      group_id = first_present(data["group_id"], group["id"], group["group_id"])
      accepted_at = first_present(data["accepted_at"], data["submitted_at"], data["created_at"])
      completed_at = first_present(data["completed_at"], data["finished_at"])
      results = first_present(data["results"], data["result"])

      new(
        request_id:,
        group_id:,
        accepted_at:,
        completed_at:,
        results:,
        raw_payload: data.merge(
          "request_id" => request_id,
          "group_id" => group_id,
          "accepted_at" => accepted_at,
          "completed_at" => completed_at,
          "results" => results
        ).compact
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

    def self.resource_payload(attributes)
      %w[
        data
        care_member_sync
        member_sync
        member_sync_request
        group_member_sync
        group_member_sync_request
        sync
        resource
        object
      ].reduce(attributes) do |payload, key|
        value = payload[key]
        !value.nil? && value.respond_to?(:to_h) ? value.to_h.stringify_keys : payload
      end
    end

    def self.nested_payload(attributes, key)
      value = attributes[key]
      value.respond_to?(:to_h) ? value.to_h.stringify_keys : {}
    end

    def self.first_present(*values)
      values.compact_blank.first
    end

    private_class_method :resource_payload, :nested_payload, :first_present

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
