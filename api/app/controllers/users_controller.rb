class UsersController < ApplicationController
  before_action :authenticate_user!

  def show
    render json: profile_data
  end

  def update
    if current_user.update(user_params)
      render json: profile_data
    else
      render json: { errors: current_user.errors.full_messages },
             status: :unprocessable_entity
    end
  end

  private

  def user_params
    params.require(:user).permit(
      :first_name,
      :last_name,
      :phone,
      :birth_date,
      :city,
      :preferred_locale
    )
  end

  def profile_data
    current_user.as_json(
      only: [
        :id,
        :email,
        :first_name,
        :last_name,
        :phone,
        :birth_date,
        :avatar_url,
        :city,
        :preferred_locale
      ]
    )
  end
end