module Documents
  CenterDto = Data.define(
    :employer,
    :metrics,
    :documents,
    :employees,
    :requirements,
    :exceptions,
    :batches,
    :batch_lines,
    :batch_holdbacks,
    :batch_payload
  ) do
    def attention_documents
      documents.select(&:attention?)
    end

    def expiring_documents
      documents.select { |document| document.attention_status == "needs_review" && document.expires_on.present? }
    end

    def requested_documents
      documents.select(&:requested?)
    end

    def latest_batch
      batches.first
    end
  end
end
