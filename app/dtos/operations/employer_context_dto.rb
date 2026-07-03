module Operations
  EmployerContextDto = Data.define(:id, :name, :organization_name) do
    def self.from_record(record)
      return unless record

      new(id: record.id, name: record.name, organization_name: record.organization.name)
    end
  end
end
