module Vitable
  RemoteEmployerDto = Data.define(
    :remote_employer_id,
    :organization_id,
    :reference_id,
    :name,
    :legal_name,
    :ein,
    :email,
    :phone_number,
    :active,
    :status,
    :address,
    :created_at,
    :updated_at,
    :raw_payload
  ) do
    def self.from_hash(payload)
      attributes = payload.respond_to?(:to_h) ? payload.to_h.stringify_keys : {}
      data = attributes.fetch("data", attributes)
      data = data.fetch("employer", data) if data.respond_to?(:fetch)
      data = data.respond_to?(:to_h) ? data.to_h.stringify_keys : {}

      new(
        remote_employer_id: first_present(data["id"], data["employer_id"]),
        organization_id: first_present(data["organization_id"], data["organization_external_id"]),
        reference_id: first_present(data["reference_id"], data["external_reference_id"]),
        name: data["name"],
        legal_name: data["legal_name"],
        ein: data["ein"],
        email: data["email"],
        phone_number: first_present(data["phone_number"], data["phone"]),
        active: data.fetch("active", nil),
        status: data["status"],
        address: address_from(data["address"]),
        created_at: data["created_at"],
        updated_at: data["updated_at"],
        raw_payload: data
      )
    end

    def validate_identity!(response_label:)
      reference = reference_id.presence || name.presence || "unknown employer"
      raise ArgumentError, "#{response_label} #{reference} did not include a remote employer ID" if remote_employer_id.blank?

      self
    end

    def validate_create!(expected_reference_id:)
      raise ArgumentError, "Vitable employer create response did not include a remote employer ID" if remote_employer_id.blank?
      if expected_reference_id.present? && reference_id.present? && reference_id != expected_reference_id
        raise ArgumentError, "Vitable employer create response returned reference_id #{reference_id}, expected #{expected_reference_id}"
      end

      self
    end

    def remote_status
      return "active" if active == true
      return "inactive" if active == false

      status
    end

    def settings_metadata(source:, refreshed_at:, matched_by: nil)
      {
        "vitable_remote_status" => remote_status,
        "vitable_remote_reference_id" => reference_id,
        "vitable_remote_organization_id" => organization_id,
        "vitable_last_refreshed_at" => refreshed_at,
        "vitable_last_snapshot_source" => source,
        "vitable_last_snapshot_matched_by" => matched_by,
        "vitable_remote_employer" => summary
      }.compact
    end

    def summary
      {
        "id" => remote_employer_id,
        "organization_id" => organization_id,
        "name" => name,
        "legal_name" => legal_name,
        "ein" => ein,
        "reference_id" => reference_id,
        "email" => email,
        "phone_number" => phone_number,
        "status" => status,
        "active" => active,
        "address" => address,
        "created_at" => created_at,
        "updated_at" => updated_at
      }.compact
    end

    def self.address_from(value)
      return unless value.respond_to?(:to_h)

      attributes = value.to_h.stringify_keys
      {
        "address_line_1" => first_present(attributes["address_line_1"], attributes["line1"], attributes["street1"]),
        "address_line_2" => first_present(attributes["address_line_2"], attributes["line2"], attributes["street2"]),
        "city" => attributes["city"],
        "state" => attributes["state"],
        "zipcode" => first_present(attributes["zipcode"], attributes["zip_code"], attributes["postal_code"])
      }.compact
    end

    def self.first_present(*values)
      values.compact_blank.first
    end

    private_class_method :address_from, :first_present
  end
end
