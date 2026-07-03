module Compliance
  AcknowledgeNoticeDto = Data.define(:notice_id, :acknowledged_by) do
    def self.from_params(params)
      attributes = ApplicationDto.coerce_hash(params)

      new(
        notice_id: attributes.fetch(:id) { attributes.fetch("id") }.to_i,
        acknowledged_by: attributes.fetch("acknowledged_by", "compliance_admin")
      )
    end
  end
end
