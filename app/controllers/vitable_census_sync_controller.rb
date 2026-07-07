class VitableCensusSyncController < ApplicationController
  def show
    @census = Vitable::CensusSyncQuery.new.call
  end

  def generate_manifest
    dto = Vitable::GenerateCensusManifestDto.from_params(params)
    result = Vitable::GenerateCensusManifestCommand.new(dto:).call

    redirect_to vitable_census_sync_path, notice: result.success? ? "Vitable census manifest generated." : result.errors.to_sentence
  end

  def submit
    dto = Vitable::SubmitCensusSyncDto.from_params(params)
    result = Vitable::SubmitCensusSyncCommand.new(dto:).call

    redirect_to vitable_census_sync_path, notice: result.success? ? "Vitable census sync submitted." : result.errors.to_sentence
  end

  def refresh_remote_roster
    dto = Vitable::RefreshRemoteRosterDto.from_params(params)
    result = Vitable::RefreshRemoteRosterCommand.new(dto:).call

    redirect_to vitable_census_sync_path, notice: result.success? ? "Vitable remote roster refreshed." : result.errors.to_sentence
  end
end
