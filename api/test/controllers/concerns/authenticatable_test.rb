require "test_helper"

# Probe the opt-in authentication concern without adding application endpoints.
class AuthenticationProbeController < ApplicationController
  before_action :authenticate_user!

  def show
    render json: { user_id: current_user.id }
  end
end

class AuthenticatableTest < ActionController::TestCase
  include AuthenticationHelpers

  tests AuthenticationProbeController

  setup do
    @user = create_user
    @routes = ActionDispatch::Routing::RouteSet.new
    @routes.draw { get "probe" => "authentication_probe#show" }
  end

  test "valid access tokens authenticate their subject and ignore another user ID" do
    other_user = create_user
    @request.headers["Authorization"] = "Bearer #{JwtService.encode(@user)}"

    get :show, params: { user_id: other_user.id }

    assert_response :ok
    assert_equal @user.id, response.parsed_body.fetch("user_id")
  end

  test "missing access tokens and incorrect authorization schemes are rejected" do
    [ nil, "Bearer", "Basic #{JwtService.encode(@user)}" ].each do |header|
      @request.headers["Authorization"] = header
      get :show
      assert_error :unauthorized, "UNAUTHORIZED"
    end
  end

  test "expired access tokens have a distinct error" do
    @request.headers["Authorization"] = "Bearer #{signed_token(exp: 1.second.ago.to_i)}"

    get :show

    assert_error :unauthorized, "TOKEN_EXPIRED"
  end

  test "invalid signatures algorithms issuers and malformed access tokens are rejected" do
    tokens = [ "invalid-token", signed_token(secret: "incorrect-secret"),
      signed_token(algorithm: "HS512"), signed_token(iss: "another-issuer") ]
    tokens.each do |token|
      @request.headers["Authorization"] = "Bearer #{token}"
      get :show
      assert_error :unauthorized, "UNAUTHORIZED"
    end
  end

  test "access tokens without required claims are rejected" do
    [ :sub, :exp ].each do |claim|
      @request.headers["Authorization"] = "Bearer #{signed_token(omit: claim)}"
      get :show
      assert_error :unauthorized, "UNAUTHORIZED"
    end
  end

  test "a token for a nonexistent user is rejected" do
    missing_user = create_user
    @request.headers["Authorization"] = "Bearer #{JwtService.encode(missing_user)}"
    missing_user.destroy!

    get :show

    assert_error :unauthorized, "UNAUTHORIZED"
  end

  test "inactive and deleted accounts cannot use existing access tokens" do
    @request.headers["Authorization"] = "Bearer #{JwtService.encode(@user)}"
    [ { is_active: false }, { is_active: true, deleted_at: Time.current } ].each do |state|
      @user.update!(state)
      get :show
      assert_error :unauthorized, "UNAUTHORIZED"
    end
  end

  test "blocked accounts cannot use existing access tokens" do
    @request.headers["Authorization"] = "Bearer #{JwtService.encode(@user)}"
    @user.update!(blocked_at: Time.current, block_reason: "Spam")

    get :show

    assert_error :forbidden, "USER_BLOCKED"
    assert_equal "Spam", response.parsed_body.fetch("details").first.fetch("message")
  end

  private

  def signed_token(secret: ENV["JWT_SECRET"].presence || Rails.application.secret_key_base,
    algorithm: JwtService::ALGORITHM, omit: nil, **claims)
    payload = { sub: @user.id.to_s, iss: JwtService::ISSUER, iat: Time.current.to_i, exp: 1.minute.from_now.to_i }.merge(claims)
    payload.delete(omit)
    JWT.encode(payload, secret, algorithm)
  end
end
