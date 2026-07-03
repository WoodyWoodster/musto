module People
  DirectoryCenterDto = Data.define(
    :employer,
    :metrics,
    :employees,
    :managers,
    :departments,
    :unassigned_employees,
    :issues,
    :snapshot,
    :snapshot_issues
  ) do
    def generated?
      snapshot.present?
    end
  end
end
