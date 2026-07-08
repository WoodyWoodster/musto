module Vitable
  WidgetLaunchTokenDto = Data.define(:scope, :employer_id, :employee_id, :issued_at, :expires_at) do
    SCOPES = %w[employer employee].freeze

    def self.from_hash(payload)
      attributes = payload.to_h.stringify_keys

      new(
        scope: attributes.fetch("scope"),
        employer_id: attributes.fetch("employer_id").to_i,
        employee_id: attributes.fetch("employee_id", nil).presence&.to_i,
        issued_at: parse_time(attributes.fetch("issued_at")),
        expires_at: parse_time(attributes.fetch("expires_at"))
      )
    end

    def self.parse_time(value)
      return value if value.respond_to?(:iso8601)

      Time.iso8601(value.to_s)
    end

    def to_claims
      {
        "scope" => scope,
        "employer_id" => employer_id,
        "employee_id" => employee_id,
        "issued_at" => issued_at.iso8601,
        "expires_at" => expires_at.iso8601
      }.compact
    end

    def valid_claims?
      return false unless scope.in?(SCOPES)
      return false unless employer_id.to_i.positive?
      return false if scope == "employee" && employee_id.to_i <= 0

      true
    end

    def expired?(at: Time.current)
      expires_at <= at
    end

    def authorizes?(request_dto, at: Time.current)
      return false unless valid_claims?
      return false if expired?(at:)
      return false unless scope == request_dto.bound_entity_type
      return false if request_dto.employer_id.present? && request_dto.employer_id.to_i != employer_id
      return false if scope == "employee" && request_dto.employee_id.to_i != employee_id

      true
    end
  end
end
