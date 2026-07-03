class BenefitsReconciliationsController < ApplicationController
  def show
    @reconciliation = Benefits::ReconciliationQuery.new.call
  end

  def resolve
    dto = Benefits::ResolveReconciliationItemDto.from_params(params)
    result = Benefits::ResolveReconciliationItemCommand.new(dto:).call

    redirect_to(
      benefits_reconciliation_path,
      notice: result.success? ? "Benefit deduction reconciled." : result.errors.to_sentence
    )
  end
end
