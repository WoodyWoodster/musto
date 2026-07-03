class PayStatementsController < ApplicationController
  def show
    @statements = PayStatements::CenterQuery.new.call
  end

  def generate_batch
    dto = PayStatements::GenerateBatchDto.from_params(params)
    result = PayStatements::GenerateBatchCommand.new(dto:).call

    redirect_to pay_statements_path, notice: result.success? ? "Pay statement batch generated." : result.errors.to_sentence
  end

  def deliver_statement
    dto = PayStatements::DeliverStatementDto.from_params(params)
    result = PayStatements::DeliverStatementCommand.new(dto:).call

    redirect_to pay_statements_path, notice: result.success? ? "Pay statement delivered." : result.errors.to_sentence
  end
end
