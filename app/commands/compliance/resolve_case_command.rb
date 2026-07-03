module Compliance
  class ResolveCaseCommand < ApplicationCommand
    def initialize(compliance_case:)
      @compliance_case = compliance_case
    end

    def call
      @compliance_case.update!(status: "resolved", resolved_at: Time.current)
      success(record: @compliance_case)
    rescue ActiveRecord::RecordInvalid => e
      failure(record: @compliance_case, errors: e.record.errors.full_messages)
    end
  end
end
