module Reports
  ReportCardDto = Data.define(:key, :title, :description, :value, :status, :cadence, :owner, :path)
end
