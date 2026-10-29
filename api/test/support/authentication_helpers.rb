module AuthenticationHelpers
  extend ActiveSupport::Concern

  PASSWORD = "Password123!".freeze

  included do
    # Threaded tests and lock-testing workers need separate committed connections.
    self.use_transactional_tests = false
    teardown :cleanup_authentication_users
  end

  def create_user(**attributes)
    user = User.create!(email: "#{SecureRandom.uuid}@example.test", password: PASSWORD,
      is_active: true, is_email_confirmed: true, **attributes)
    (@authentication_users ||= []) << user
    user
  end

  def assert_error(status, code)
    assert_response status
    assert_equal code, response.parsed_body.fetch("code")
    assert_kind_of Array, response.parsed_body.fetch("details")
  end

  private

  def cleanup_authentication_users
    ids = Array(@authentication_users).map(&:id)
    RefreshToken.where(user_id: ids).delete_all
    User.where(id: ids).delete_all
  end
end
