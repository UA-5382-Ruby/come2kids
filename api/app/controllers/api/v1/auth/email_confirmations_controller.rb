module Api
  module V1
    module Auth
      class EmailConfirmationsController < ApplicationController
        def confirm
          user = Accounts::ConfirmEmail.call(params.require(:token).to_s)

          render json: {
            message: I18n.t("auth.email_confirmed"),
            user: UserSerializer.new(user)
          }
        end

        def resend
          Accounts::ResendConfirmation.call(params.require(:email).to_s)
          render json: { message: I18n.t("auth.confirmation_resent") }
        end
      end
    end
  end
end
