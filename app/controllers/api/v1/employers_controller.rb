module Api
  module V1
    class EmployersController < ApplicationController
      protect_from_forgery with: :null_session

      def create
        dto = Employers::EmployerDto.from_params(employer_params)
        result = Employers::CreateEmployerCommand.new(dto:).call

        if result.success?
          render json: EmployerSerializer.new(result.record).as_json, status: :created
        else
          render json: { errors: result.errors }, status: :unprocessable_entity
        end
      rescue KeyError => e
        render json: { errors: [ "Missing required field: #{e.key}" ] }, status: :bad_request
      end

      def show
        employer = Employer.find(params[:id])
        render json: EmployerSerializer.new(employer).as_json
      end

      private

      def employer_params
        params.require(:employer).permit(:organization_id, :name, :legal_name, :ein, :status, settings: {})
      end
    end
  end
end
