module Garnishments
  IssueDto = Data.define(:deduction_id, :employee_name, :title, :deduction_type, :agency_name, :case_number, :amount_cents, :status, :reason) do
    def self.from_hash(payload)
      attributes = payload.to_h.stringify_keys

      new(
        deduction_id: attributes.fetch("deduction_id", nil),
        employee_name: attributes.fetch("employee_name", "Garnishment program"),
        title: attributes.fetch("title", "Agency remittance"),
        deduction_type: attributes.fetch("deduction_type", "child_support"),
        agency_name: attributes.fetch("agency_name", nil),
        case_number: attributes.fetch("case_number", nil),
        amount_cents: attributes.fetch("amount_cents", 0),
        status: attributes.fetch("status", "needs_review"),
        reason: attributes.fetch("reason", "Needs review")
      )
    end
  end
end
