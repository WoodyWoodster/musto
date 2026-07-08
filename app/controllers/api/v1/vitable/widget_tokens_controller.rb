module Api
  module V1
    module Vitable
      class WidgetTokensController < ApplicationController
        protect_from_forgery with: :null_session

        def create_employer
          issue(::Vitable::WidgetTokenRequestDto.employer_from_params(params))
        end

        def create_employee
          issue(::Vitable::WidgetTokenRequestDto.employee_from_params(params))
        end

        private

        def issue(dto)
          result = ::Vitable::IssueWidgetTokenCommand.new(dto:).call

          if result.success?
            render json: result.value.to_h, status: :created
          else
            render json: { errors: result.errors }, status: status_for(result.record&.status)
          end
        end

        def status_for(sync_status)
          case sync_status
          when "needs_credentials"
            :unauthorized
          when "blocked"
            :unprocessable_entity
          else
            :bad_request
          end
        end
      end
    end
  end
end
