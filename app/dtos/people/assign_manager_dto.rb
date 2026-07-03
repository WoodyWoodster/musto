module People
  AssignManagerDto = Data.define(:employee_id, :manager_id, :assigned_by) do
    def self.from_params(params)
      attributes = ApplicationDto.coerce_hash(params)

      new(
        employee_id: attributes.fetch(:employee_id) { attributes.fetch("employee_id") }.to_i,
        manager_id: attributes.fetch(:manager_id) { attributes.fetch("manager_id") }.to_i,
        assigned_by: attributes.fetch(:assigned_by) { attributes.fetch("assigned_by", "ops_console") }
      )
    end
  end
end
