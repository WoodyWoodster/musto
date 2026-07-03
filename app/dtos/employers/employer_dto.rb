module Employers
  EmployerDto = Data.define(:organization_id, :name, :legal_name, :ein, :status, :settings) do
    def self.from_params(params)
      attrs = ApplicationDto.coerce_hash(params).symbolize_keys

      new(
        organization_id: attrs.fetch(:organization_id),
        name: attrs.fetch(:name),
        legal_name: attrs[:legal_name],
        ein: attrs[:ein],
        status: attrs[:status].presence || "draft",
        settings: attrs[:settings] || {}
      )
    end

    def to_attributes
      {
        organization_id:,
        name:,
        legal_name:,
        ein:,
        status:,
        settings:
      }
    end
  end
end
