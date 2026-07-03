module Compliance
  ResolveNoticeDto = Data.define(:notice_id, :resolved_by, :resolution_summary) do
    def self.from_params(params)
      attributes = ApplicationDto.coerce_hash(params)

      new(
        notice_id: attributes.fetch(:id) { attributes.fetch("id") }.to_i,
        resolved_by: attributes.fetch("resolved_by", "compliance_admin"),
        resolution_summary: attributes.fetch("resolution_summary", nil)
      )
    end
  end
end
