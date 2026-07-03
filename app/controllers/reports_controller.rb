class ReportsController < ApplicationController
  def show
    @reports = Reports::CenterQuery.new.call
  end

  def generate_snapshot
    dto = Reports::GenerateSnapshotDto.from_params(params)
    result = Reports::GenerateSnapshotCommand.new(dto:).call

    redirect_to reports_path, notice: result.success? ? "Report snapshot generated." : result.errors.to_sentence
  end
end
