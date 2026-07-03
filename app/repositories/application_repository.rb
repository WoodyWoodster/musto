class ApplicationRepository
  private

  def severity_sort
    Arel.sql("CASE severity WHEN 'critical' THEN 0 WHEN 'high' THEN 1 WHEN 'medium' THEN 2 ELSE 3 END")
  end
end
