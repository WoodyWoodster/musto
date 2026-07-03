class ApplicationCommand
  Result = Data.define(:success, :record, :value, :errors) do
    def success?
      success
    end

    def failure?
      !success
    end
  end

  private

  def success(record: nil, value: nil)
    Result.new(success: true, record:, value:, errors: [])
  end

  def failure(errors:, record: nil, value: nil)
    Result.new(success: false, record:, value:, errors: Array(errors))
  end
end
