require "test_helper"

class AuthControllerTest < ActionDispatch::IntegrationTest
  include AuthenticationHelpers

  setup do
    @user = create_user
    # Isolate rate-limit keys while retaining the shared in-memory test cache.
    @headers = { "REMOTE_ADDR" => "fd00:#{SecureRandom.hex(2)}:#{SecureRandom.hex(2)}:#{SecureRandom.hex(2)}::1" }
    @csrf_headers = @headers.merge("X-Requested-With" => "XMLHttpRequest")
  end

  test "login normalizes email and returns an access token and a hashed refresh cookie" do
    assert_difference "RefreshToken.where(user: @user).count", 1 do
      login(email: "  #{@user.email.upcase}  ")
    end

    assert_response :ok
    assert_equal @user.id.to_s, JwtService.decode(response.parsed_body.fetch("access_token")).fetch("sub")
    assert_equal "Bearer", response.parsed_body.fetch("token_type")
    assert_equal JwtService.access_ttl.to_i, response.parsed_body.fetch("expires_in")
    assert_equal %w[access_token expires_in token_type], response.parsed_body.keys.sort

    raw_token = cookies[:refresh_token]
    token = RefreshToken.find_by_raw(raw_token)
    assert_equal @user.id, token.user_id
    assert_not_equal raw_token, token.token_digest
    assert_equal RefreshToken.digest(raw_token), token.token_digest
    assert_match(/httponly/i, response.headers["Set-Cookie"].to_s)
    assert_match(/samesite=strict/i, response.headers["Set-Cookie"].to_s)
    assert_match(/path=\/auth/i, response.headers["Set-Cookie"].to_s)
  end

  test "wrong passwords and unknown emails return the same credentials error" do
    assert_no_difference "RefreshToken.where(user: @user).count" do
      login(password: "wrong-password")
      assert_error :unauthorized, "INVALID_CREDENTIALS"
      error = response.parsed_body

      login(email: "missing@example.test")
      assert_error :unauthorized, "INVALID_CREDENTIALS"
      assert_equal error, response.parsed_body
    end
  end

  test "missing credentials return field errors" do
    login(email: " ", password: "")

    assert_error :unprocessable_content, "VALIDATION_ERROR"
    assert_equal %w[email password], response.parsed_body.fetch("details").map { |detail| detail.fetch("field") }
  end

  test "unconfirmed accounts cannot log in" do
    @user.update!(is_email_confirmed: false)

    assert_no_difference "RefreshToken.where(user: @user).count" do
      login
    end
    assert_error :forbidden, "EMAIL_NOT_CONFIRMED"
  end

  test "blocked accounts receive their block reason" do
    @user.update!(blocked_at: Time.current, block_reason: "Spam")

    assert_no_difference "RefreshToken.where(user: @user).count" do
      login
    end
    assert_error :forbidden, "USER_BLOCKED"
    assert_equal [ { "field" => "block_reason", "message" => "Spam" } ], response.parsed_body.fetch("details")
  end

  test "inactive and deleted accounts cannot log in" do
    [ { is_active: false }, { is_active: true, deleted_at: Time.current } ].each do |state|
      @user.update!(state)
      assert_no_difference "RefreshToken.where(user: @user).count" do
        login
      end
      assert_error :unauthorized, "INVALID_CREDENTIALS"
    end
  end

  test "refresh rotates the cookie and revokes the predecessor" do
    token, raw_token = RefreshToken.issue_for(@user)
    set_refresh_cookie(raw_token)

    assert_difference "RefreshToken.where(user: @user).count", 1 do
      refresh
    end

    assert_response :ok
    successor = RefreshToken.find_by_raw(cookies[:refresh_token])
    assert_not_equal raw_token, cookies[:refresh_token]
    assert_predicate token.reload, :revoked?
    assert_equal successor, token.replaced_by
    assert_predicate successor, :active?
    assert_equal @user.id.to_s, JwtService.decode(response.parsed_body.fetch("access_token")).fetch("sub")
  end

  test "reuse immediately revokes every session of only the token owner" do
    token, raw_token = RefreshToken.issue_for(@user)
    successor, = token.rotate!
    sibling, = RefreshToken.issue_for(@user)
    other_session, = RefreshToken.issue_for(create_user)
    set_refresh_cookie(raw_token)

    # Spoofed ownership parameters must not change whose sessions are revoked.
    refresh(user_id: other_session.user_id)

    assert_error :unauthorized, "INVALID_REFRESH_TOKEN"
    assert_predicate successor.reload, :revoked?
    assert_predicate sibling.reload, :revoked?
    assert_predicate other_session.reload, :active?
    assert_cookie_deleted
  end

  test "a request losing rotation leaves the winning cookie and session alone" do
    token, raw_token = RefreshToken.issue_for(@user)
    set_refresh_cookie(raw_token)
    successor = nil
    request_thread = Thread.current
    rotated = false

    # Interleave a winning rotation after this request's SELECT has read the
    # active token. The request then sees a stale record and rotate! returns nil.
    callback = lambda do |event|
      if Thread.current == request_thread && !rotated && event.payload[:name] == "RefreshToken Load"
        rotated = true
        successor, = RefreshToken.find(token.id).rotate!
      end
    end
    ActiveSupport::Notifications.subscribed(callback, "sql.active_record") { refresh }

    assert rotated
    assert_error :unauthorized, "INVALID_REFRESH_TOKEN"
    assert_nil response.headers["Set-Cookie"]
    assert_predicate successor.reload, :active?
    assert_equal successor, token.reload.replaced_by
  end

  test "missing invalid and expired refresh tokens are rejected and clear the cookie" do
    token, raw_token = RefreshToken.issue_for(@user)
    token.update!(expires_at: 1.second.ago)

    [ nil, "invalid-token", raw_token ].each do |value|
      set_refresh_cookie(value)
      assert_no_difference "RefreshToken.where(user: @user).count" do
        refresh
      end
      assert_error :unauthorized, "INVALID_REFRESH_TOKEN"
      assert_cookie_deleted if value
    end
  end

  test "inactive and deleted accounts lose all refresh sessions" do
    [ { is_active: false }, { is_active: true, deleted_at: Time.current } ].each do |state|
      @user.update!(state)
      _token, raw_token = RefreshToken.issue_for(@user)
      sibling, = RefreshToken.issue_for(@user)
      set_refresh_cookie(raw_token)

      refresh

      assert_error :unauthorized, "INVALID_REFRESH_TOKEN"
      assert_empty RefreshToken.active.where(user: @user)
      assert_predicate sibling.reload, :revoked?
      assert_cookie_deleted
    end
  end

  test "blocked accounts cannot refresh and lose all refresh sessions" do
    _token, raw_token = RefreshToken.issue_for(@user)
    RefreshToken.issue_for(@user)
    @user.update!(blocked_at: Time.current, block_reason: "Spam")
    set_refresh_cookie(raw_token)

    refresh

    assert_error :forbidden, "USER_BLOCKED"
    assert_equal "Spam", response.parsed_body.fetch("details").first.fetch("message")
    assert_empty RefreshToken.active.where(user: @user)
    assert_cookie_deleted
  end

  test "refresh and logout require the CSRF header before changing any session" do
    token, raw_token = RefreshToken.issue_for(@user)
    set_refresh_cookie(raw_token)

    [ auth_refresh_path, auth_logout_path ].each do |path|
      assert_no_difference "RefreshToken.where(user: @user).count" do
        post path, headers: @headers
      end
      assert_error :forbidden, "CSRF_HEADER_MISSING"
      assert_predicate token.reload, :active?
      assert_nil response.headers["Set-Cookie"]
    end
  end

  test "logout revokes only the cookie session despite spoofed user and token IDs" do
    token, raw_token = RefreshToken.issue_for(@user)
    sibling, = RefreshToken.issue_for(@user)
    other_session, = RefreshToken.issue_for(create_user)
    set_refresh_cookie(raw_token)

    post auth_logout_path, params: { user_id: other_session.user_id, token_id: other_session.id }, headers: @csrf_headers

    assert_response :no_content
    assert_predicate token.reload, :revoked?
    assert_predicate sibling.reload, :active?
    assert_predicate other_session.reload, :active?
    assert_cookie_deleted
  end

  test "logout without a known token is idempotent" do
    set_refresh_cookie("invalid-token")
    2.times do
      post auth_logout_path, headers: @csrf_headers
      assert_response :no_content
    end
  end

  test "login rate limits a normalized email using the memory cache" do
    assert_kind_of ActiveSupport::Cache::MemoryStore, Rails.cache
    5.times do
      login(email: "  #{@user.email.upcase}  ", password: "wrong-password")
      assert_response :unauthorized
    end

    login(password: "wrong-password")

    assert_error :too_many_requests, "TOO_MANY_REQUESTS"
  end

  test "login rate limits an IP even when emails change" do
    20.times do
      login(email: "#{SecureRandom.uuid}@example.test", password: "wrong-password")
      assert_response :unauthorized
    end

    login

    assert_error :too_many_requests, "TOO_MANY_REQUESTS"
  end

  test "refresh rate limits an IP" do
    30.times do
      refresh
      assert_response :unauthorized
    end

    refresh

    assert_error :too_many_requests, "TOO_MANY_REQUESTS"
  end

  private

  def login(email: @user.email, password: AuthenticationHelpers::PASSWORD)
    post auth_login_path, params: { email: email, password: password }, headers: @headers, as: :json
  end

  def refresh(**params)
    post auth_refresh_path, params: params, headers: @csrf_headers, as: :json
  end

  def set_refresh_cookie(value)
    cookies.delete(:refresh_token)
    cookies.merge("refresh_token=#{value}; path=/auth") if value
  end

  def assert_cookie_deleted
    assert_match(/refresh_token=;.*path=\/auth;.*max-age=0/i, response.headers["Set-Cookie"].to_s)
  end
end
