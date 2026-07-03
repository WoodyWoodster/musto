module PayStatements
  class DeliverStatementCommand < ApplicationCommand
    def initialize(dto:, repository: StatementRepository.new)
      @dto = dto
      @repository = repository
    end

    def call
      statement = @repository.find_statement(@dto.statement_id)

      if @repository.deliver_statement(statement, delivered_by: @dto.delivered_by)
        success(record: statement.reload)
      else
        failure(record: statement.reload, errors: "Voided pay statements cannot be delivered")
      end
    rescue ActiveRecord::RecordInvalid => e
      failure(record: e.record, errors: e.record.errors.full_messages)
    end
  end
end
