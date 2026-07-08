module Api
  module V1
    module Vitable
      class WidgetTokensController < ApplicationController
        BROKER_SECRET_REFERENCE = "VITABLE_WIDGET_TOKEN_BROKER_SECRET"
        BROKER_SECRET_HEADER = "X-Musto-Widget-Token"
        LAUNCH_TOKEN_HEADER = ::Vitable::WidgetLaunchToken::HEADER

        protect_from_forgery with: :null_session

        def create_employer
          dto = ::Vitable::WidgetTokenRequestDto.employer_from_params(params)
          authorized_dto = authorize_widget_token_request(dto)
          issue(authorized_dto) if authorized_dto
        end

        def create_employee
          dto = ::Vitable::WidgetTokenRequestDto.employee_from_params(params)
          authorized_dto = authorize_widget_token_request(dto)
          issue(authorized_dto) if authorized_dto
        end

        private

        def authorize_widget_token_request(dto)
          return dto if authorized_by_broker_secret?
          return nil if performed?

          launch_verification = verify_launch_token
          if launch_verification.success?
            return dto_for_launch_claims(dto, launch_verification.claims) if launch_verification.claims.authorizes?(dto)

            render json: { errors: [ "Signed widget launch token does not match this token request" ] }, status: :unauthorized
            return nil
          end

          return broker_secret_unauthorized if launch_token_supplied?
          return broker_secret_not_configured if broker_secret_missing?

          broker_secret_unauthorized
        end

        def authorized_by_broker_secret?
          supplied_secret = request.headers[BROKER_SECRET_HEADER].to_s
          return false if supplied_secret.blank?
          return broker_secret_not_configured if broker_secret_missing?
          return true if secure_secret_match?(supplied_secret, expected_secret)

          broker_secret_unauthorized
        end

        def verify_launch_token
          ::Vitable::WidgetLaunchToken.verify(launch_token)
        end

        def launch_token
          request.headers[LAUNCH_TOKEN_HEADER].presence || params[:launch_token].presence
        end

        def launch_token_supplied?
          launch_token.present?
        end

        def expected_secret
          ENV.fetch(BROKER_SECRET_REFERENCE, nil).to_s
        end

        def broker_secret_missing?
          expected_secret.blank?
        end

        def dto_for_launch_claims(dto, claims)
          ::Vitable::WidgetTokenRequestDto.new(
            bound_entity_type: dto.bound_entity_type,
            employer_id: claims.employer_id,
            employee_id: dto.employee_id,
            requested_by: dto.requested_by
          )
        end

        def secure_secret_match?(supplied_secret, expected_secret)
          supplied_secret.bytesize == expected_secret.bytesize &&
            ActiveSupport::SecurityUtils.secure_compare(supplied_secret, expected_secret)
        end

        def broker_secret_not_configured
          render(
            json: { errors: [ "#{BROKER_SECRET_REFERENCE} is not configured and no signed widget launch token was accepted" ] },
            status: :service_unavailable
          )
          nil
        end

        def broker_secret_unauthorized
          render(
            json: { errors: [ "Widget token broker authorization is required" ] },
            status: :unauthorized
          )
          nil
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
