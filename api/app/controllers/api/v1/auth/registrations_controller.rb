module Api
  module V1
    module Auth
      class RegistrationsController < ApplicationController
        def create
          user = Accounts::Register.call(registration_params)

          render json: {
            message: I18n.t("auth.registered"),
            user: UserSerializer.new(user)
          }, status: :created
        end

        private

        def registration_params
          permitted = params.permit(:email, :password, :password_confirmation,
                                    :first_name, :last_name, :preferred_locale).to_h
          permitted[:preferred_locale] = I18n.locale.to_s if permitted[:preferred_locale].blank?
          permitted
        end
      end
    end
  end
end
