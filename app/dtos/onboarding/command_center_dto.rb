module Onboarding
  CommandCenterDto = Data.define(:employer, :metrics, :readiness, :tasks, :documents, :lanes) do
    def ready_employees
      readiness.select(&:ready?)
    end

    def blocked_employees
      readiness.select(&:blocked?)
    end

    def attention_documents
      documents.select(&:attention?)
    end
  end
end
