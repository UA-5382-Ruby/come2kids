class UsersController < ApplicationController
  def show
  end

  def update
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
end

