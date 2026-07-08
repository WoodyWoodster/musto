module Api
  module V1
    module Webhooks
      class VitableController < ApplicationController
        protect_from_forgery with: :null_session

        def create
          request_dto = ::Vitable::WebhookRequestDto.from_request(request, webhook_payload)
          signature = ::Vitable::WebhookSignatureVerifier.new.verify(request_dto)
          return render_signature_rejection(signature) if signature.rejected?

          result = ::Vitable::ProcessWebhookCommand.new(payload: request_dto.payload, signature_verification: signature).call

          if result.success?
            render json: { status: "accepted", event_id: result.record&.event_id, outcome: result.value, signature: signature.status }, status: :accepted
          else
            render json: { status: "rejected", errors: result.errors }, status: :unprocessable_entity
          end
        end

        private

        def render_signature_rejection(signature)
          render json: { status: "rejected", errors: signature.detail, signature: signature.status }, status: :unauthorized
        end

        def webhook_payload
          request.request_parameters.deep_dup
        end
      end
    end
  end
end
