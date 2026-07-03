module OpenEnrollment
  IssueDto = Data.define(:key, :title, :detail, :severity, :status, :owner, :count, :action_path)
end
