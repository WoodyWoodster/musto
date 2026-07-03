module PayrollFunding
  class VerifyEmployeeAccountCommand < ApplicationCommand
    def initialize(dto:, repository: FundingRepository.new)
      @dto = dto
      @repository = repository
    end

    def call
      account = @repository.find_employee_account(@dto.employee_account_id)

      if @repository.verify_employee_account(account, reviewed_by: @dto.reviewed_by)
        success(record: account.reload)
      else
        failure(record: account.reload, errors: "Blocked bank accounts cannot be verified until the account exception is cleared")
      end
    rescue ActiveRecord::RecordInvalid => e
      failure(record: e.record, errors: e.record.errors.full_messages)
    end
  end
end
