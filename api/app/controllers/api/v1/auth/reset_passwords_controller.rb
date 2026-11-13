# frozen_string_literal: true

module Api
  module V1
    module Auth
      class ResetPasswordsController < ApplicationController
        skip_after_action :verify_authorized

        def create
          Accounts::ResetPassword.call(
            params.require(:token).to_s,
            params.require(:password),
            params.require(:password_confirmation)
          )

          render json: { message: I18n.t('auth.password_reset_success') }, status: :ok
        rescue ActiveRecord::RecordInvalid => e
          render_validation_error(e)
        end
      end
    end
  end
end
