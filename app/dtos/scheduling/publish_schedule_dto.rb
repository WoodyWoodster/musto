module Scheduling
  PublishScheduleDto = Data.define(:published_by) do
    def self.from_params(params)
      new(published_by: ApplicationDto.coerce_hash(params).fetch("published_by", "ops_console"))
    end
  end
end
