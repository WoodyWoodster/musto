class VitableCareGroupsController < ApplicationController
  def show
    @care_group = Vitable::CareGroupQuery.new.call
  end

  def generate_group_packet
    dto = Vitable::GenerateCareGroupPacketDto.from_params(params)
    result = Vitable::GenerateCareGroupPacketCommand.new(dto:).call

    redirect_to vitable_care_groups_path, notice: result.success? ? "Care group packet generated." : result.errors.to_sentence
  end

  def submit_group
    dto = Vitable::SubmitCareGroupDto.from_params(params)
    result = Vitable::SubmitCareGroupCommand.new(dto:).call

    redirect_to vitable_care_groups_path, notice: result.success? ? "Care group submitted." : result.errors.to_sentence
  end

  def generate_member_manifest
    dto = Vitable::GenerateCareMemberSyncDto.from_params(params)
    result = Vitable::GenerateCareMemberSyncCommand.new(dto:).call

    redirect_to vitable_care_groups_path, notice: result.success? ? "Care member manifest generated." : result.errors.to_sentence
  end

  def submit_members
    dto = Vitable::SubmitCareMemberSyncDto.from_params(params)
    result = Vitable::SubmitCareMemberSyncCommand.new(dto:).call

    redirect_to vitable_care_groups_path, notice: result.success? ? "Care member sync submitted." : result.errors.to_sentence
  end

  def refresh_member_sync
    dto = Vitable::RefreshCareMemberSyncDto.from_params(params)
    result = Vitable::RefreshCareMemberSyncCommand.new(dto:).call

    redirect_to vitable_care_groups_path, notice: result.success? ? "Care member sync refreshed." : result.errors.to_sentence
  end
end
