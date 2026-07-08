module Api
  module V1
    module Vitable
      class WidgetTokensController < ApplicationController
        BROKER_SECRET_REFERENCE = "VITABLE_WIDGET_TOKEN_BROKER_SECRET"
        BROKER_SECRET_HEADER = "X-Musto-Widget-Token"

        protect_from_forgery with: :null_session
        before_action :verify_broker_secret

        def create_employer
          issue(::Vitable::WidgetTokenRequestDto.employer_from_params(params))
        end

        def create_employee
          issue(::Vitable::WidgetTokenRequestDto.employee_from_params(params))
        end

        private

        def verify_broker_secret
          expected_secret = ENV.fetch(BROKER_SECRET_REFERENCE, nil).to_s
          return broker_secret_not_configured if expected_secret.blank?

          supplied_secret = request.headers[BROKER_SECRET_HEADER].to_s
          return broker_secret_unauthorized if supplied_secret.blank?
          return if secure_secret_match?(supplied_secret, expected_secret)

          broker_secret_unauthorized
        end

        def secure_secret_match?(supplied_secret, expected_secret)
          supplied_secret.bytesize == expected_secret.bytesize &&
            ActiveSupport::SecurityUtils.secure_compare(supplied_secret, expected_secret)
        end

        def broker_secret_not_configured
          render(
            json: { errors: [ "#{BROKER_SECRET_REFERENCE} is not configured" ] },
            status: :service_unavailable
          )
        end

        def broker_secret_unauthorized
          render(
            json: { errors: [ "Widget token broker authorization is required" ] },
            status: :unauthorized
          )
        end

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
