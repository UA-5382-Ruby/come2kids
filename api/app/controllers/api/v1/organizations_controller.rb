# frozen_string_literal: true

module Api
  module V1
    class OrganizationsController < ApplicationController
      before_action :authenticate_user!
      after_action :verify_authorized

      def create
        authorize Organization

        result = ::Organizations::Create.call(
          user: current_user,
          name: organization_params[:name],
          description: organization_params[:description],
          contact_email: organization_params[:contact_email]
        )

        case result
        when Dry::Monads::Success
          render json: {
            message: I18n.t('organizations.requested'),
            organization: result.value!.as_json(only: %i[id slug status contact_email])
          }, status: :created
        when Dry::Monads::Failure
          handle_failure(result.failure)
        end
      end

      private

      def organization_params
        params.require(:organization).permit(:name, :description, :contact_email)
      end

      def handle_failure(error)
        if error == :already_owner
          render json: {
            code: 'ALREADY_OWNER',
            message: I18n.t('errors.organizations.already_owner')
          }, status: :unprocessable_content

        elsif error.is_a?(ActiveModel::Errors) || error.respond_to?(:messages)
          error_details = if error.respond_to?(:map)
                            error.map { |e| { field: e.attribute, error: e.type } }
          else
            error.messages.map { |field, messages| { field: field, error: messages.join(', ') } }
          end

          render json: {
            code: 'VALIDATION_ERROR',
            message: I18n.t('api_errors.validation_error'),
            details: error_details
          }, status: :unprocessable_content

        else
          details = case error
          when Hash then [ { field: 'base', error: error.to_s } ]
          when String then [ { field: 'base', error: error } ]
          else [ { field: 'base', error: I18n.t('api_errors.validation_error') } ]
          end

          render json: {
            code: 'VALIDATION_ERROR',
            message: I18n.t('api_errors.validation_error'),
            details: details
          }, status: :unprocessable_content
        end
      end
    end
  end
end
