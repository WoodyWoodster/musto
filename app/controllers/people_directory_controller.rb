class PeopleDirectoryController < ApplicationController
  def show
    @directory = People::DirectoryQuery.new.call
  end

  def assign_manager
    dto = People::AssignManagerDto.from_params(params)
    result = People::AssignManagerCommand.new(dto:).call

    redirect_to people_directory_path, notice: result.success? ? "Manager assignment updated." : result.errors.to_sentence
  end

  def generate_snapshot
    dto = People::GenerateDirectorySnapshotDto.from_params(params)
    result = People::GenerateDirectorySnapshotCommand.new(dto:).call

    redirect_to people_directory_path, notice: result.success? ? "People directory snapshot generated." : result.errors.to_sentence
  end
end
