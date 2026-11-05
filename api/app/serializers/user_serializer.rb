class UserSerializer
  def initialize(user)
    @user = user
  end

  def as_json(_options = nil)
    {
      id: @user.id,
      email: @user.email,
      first_name: @user.first_name,
      last_name: @user.last_name,
      preferred_locale: @user.preferred_locale,
      email_confirmed: @user.email_confirmed?,
      created_at: @user.created_at.utc.iso8601
    }
  end
end
