# frozen_string_literal: true

module Api
  module V1
    module Auth
      class ForgotPasswordsController < ApplicationController
        skip_after_action :verify_authorized

        def create
          Accounts::ForgotPassword.call(params.require(:email).to_s)

          render json: { message: I18n.t('auth.forgot_password_sent') }, status: :ok
        end
      end
    end
  end
end
