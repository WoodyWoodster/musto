module PayrollFunding
  FundingIssueDto = Data.define(:key, :title, :detail, :severity, :status, :owner, :count, :amount_cents, :action_path)
end
