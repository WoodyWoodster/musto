module Training
  ProgramDto = Data.define(:id, :title, :category, :description, :audience, :cadence, :status, :launch_on, :due_on, :required_count, :completed_count, :overdue_count, :completion_rate, :open_count) do
    def self.from_record(record)
      required_count = record.required_count
      completed_count = record.completed_count
      completion_rate = required_count.zero? ? 0 : ((completed_count.to_f / required_count) * 100).round

      new(
        id: record.id,
        title: record.title,
        category: record.category,
        description: record.description,
        audience: record.audience,
        cadence: record.cadence,
        status: record.status,
        launch_on: record.launch_on,
        due_on: record.due_on,
        required_count:,
        completed_count:,
        overdue_count: record.overdue_count,
        completion_rate:,
        open_count: [ required_count - completed_count, 0 ].max
      )
    end

    def launchable?
      status == "draft"
    end
  end
end
