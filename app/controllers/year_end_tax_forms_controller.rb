class YearEndTaxFormsController < ApplicationController
  def show
    @year_end = YearEnd::TaxFormsQuery.new(tax_year: tax_year).call
  end

  def generate_packet
    dto = YearEnd::GeneratePacketDto.from_params(params)
    result = YearEnd::GenerateTaxFormPacketCommand.new(dto:).call

    redirect_to year_end_tax_forms_path(tax_year: dto.tax_year), notice: result.success? ? "Year-end tax form packet generated." : result.errors.to_sentence
  end

  def deliver
    dto = YearEnd::DeliverFormDto.from_params(params)
    result = YearEnd::DeliverTaxFormCommand.new(dto:).call

    redirect_to year_end_tax_forms_path(tax_year: dto.tax_year), notice: result.success? ? "Year-end tax form delivered." : result.errors.to_sentence
  end

  private

  def tax_year
    params.fetch(:tax_year, Date.current.year).to_i
  end
end
