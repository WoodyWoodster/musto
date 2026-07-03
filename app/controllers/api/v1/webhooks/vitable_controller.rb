module Api
  module V1
    module Webhooks
      class VitableController < ApplicationController
        protect_from_forgery with: :null_session

        def create
          result = Vitable::ProcessWebhookCommand.new(payload: webhook_payload).call

          if result.success?
            render json: { status: "accepted", event_id: result.record&.event_id, outcome: result.value }, status: :accepted
          else
            render json: { status: "rejected", errors: result.errors }, status: :unprocessable_entity
          end
        end

        private

        def webhook_payload
          params.except(:controller, :action, :vitable).permit!.to_h
        end
      end
    end
  end
end
