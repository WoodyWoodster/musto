class TaxAgencyRegistrationsController < ApplicationController
  def show
    @registrations = Taxes::AgencyRegistrationsQuery.new.call
  end

  def submit
    dto = Taxes::SubmitAgencyRegistrationDto.from_params(params)
    result = Taxes::SubmitAgencyRegistrationCommand.new(dto:).call

    redirect_to tax_agency_registrations_path, notice: result.success? ? "Tax agency registration submitted." : result.errors.to_sentence
  end

  def generate_packet
    dto = Taxes::GenerateAgencyRegistrationPacketDto.from_params(params)
    result = Taxes::GenerateAgencyRegistrationPacketCommand.new(dto:).call

    redirect_to tax_agency_registrations_path, notice: result.success? ? "Tax agency registration packet generated." : result.errors.to_sentence
  end
end
