module Vitable
  WebhookResourceReconciliationDto = Data.define(
    :status,
    :resource_type,
    :resource_id,
    :local_record_type,
    :local_record_id,
    :matched_by,
    :applied_changes,
    :warnings
  ) do
    def to_metadata
      {
        "status" => status,
        "resource_type" => resource_type,
        "resource_id" => resource_id,
        "local_record_type" => local_record_type,
        "local_record_id" => local_record_id,
        "matched_by" => matched_by,
        "applied_changes" => applied_changes,
        "warnings" => warnings
      }.compact
    end
  end
end
