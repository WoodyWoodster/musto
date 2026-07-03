module Company
  SetupStepDto = Data.define(:key, :label, :description, :detail, :status, :critical, :completed_at, :manual) do
    def complete?
      status == "complete"
    end

    def blocked?
      status == "blocked"
    end

    def actionable?
      !complete? && key != "vitable_connection"
    end

    def manually_completed?
      manual
    end
  end
end
