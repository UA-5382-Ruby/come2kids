# frozen_string_literal: true

require "rails_helper"
require 'swagger_helper'

RSpec.describe Authenticatable, type: :controller do
  controller(ApplicationController) do
    include ErrorHandling

    # ДОДАЙ цей порожній метод, щоб "заглушити" Pundit і уникнути помилок
    def verify_authorized; end

    before_action :authenticate_user!

    def index
      render json: { user_id: current_user.id }
    end
  end

  let(:user) { create(:user) }
  let(:json) { response.parsed_body }

  def sign(omit: nil, key: JwtService::SECRET_KEY, algorithm: JwtService::ALGORITHM, **claims)
    payload = { sub: user.id.to_s, iss: JwtService::ISSUER, iat: Time.current.to_i, exp: 1.minute.from_now.to_i }
      .merge(claims)
      .except(omit)
    JWT.encode(payload, key, algorithm)
  end

  def get_with(authorization)
    request.headers["Authorization"] = authorization
    get :index
  end

  it "authenticates the token subject and ignores a user id in params" do
    other_user = create(:user)
    request.headers["Authorization"] = "Bearer #{JwtService.encode(user)}"
    get :index, params: { user_id: other_user.id }

    expect(response).to have_http_status(:ok)
    expect(json["user_id"]).to eq(user.id)
  end

  [ nil, "Bearer", "Basic token" ].each do |authorization|
    it "rejects the Authorization header #{authorization.inspect}" do
      get_with(authorization)

      expect(response).to have_http_status(:unauthorized)
      expect(json["code"]).to eq("UNAUTHORIZED")
    end
  end

  it "returns TOKEN_EXPIRED for an expired token" do
    get_with("Bearer #{sign(exp: 1.second.ago.to_i)}")

    expect(response).to have_http_status(:unauthorized)
    expect(json["code"]).to eq("TOKEN_EXPIRED")
  end

  {
    "a malformed token" => -> { "invalid-token" },
    "a wrong secret" => -> { sign(key: "incorrect-secret") },
    "another algorithm" => -> { sign(algorithm: "HS512") },
    "another issuer" => -> { sign(iss: "another-issuer") },
    "a missing sub claim" => -> { sign(omit: :sub) },
    "a missing exp claim" => -> { sign(omit: :exp) }
  }.each do |description, token|
    it "rejects a token with #{description}" do
      get_with("Bearer #{instance_exec(&token)}")

      expect(response).to have_http_status(:unauthorized)
      expect(json["code"]).to eq("UNAUTHORIZED")
    end
  end

  it "rejects a token of a user that no longer exists" do
    token = JwtService.encode(user)
    user.destroy!
    get_with("Bearer #{token}")

    expect(response).to have_http_status(:unauthorized)
  end

  { "inactive" => { is_active: false }, "soft-deleted" => { deleted_at: Time.current } }.each do |state, attributes|
    it "rejects a valid token when the account is #{state}" do
      token = JwtService.encode(user)
      user.update!(attributes)
      get_with("Bearer #{token}")

      expect(response).to have_http_status(:unauthorized)
      expect(json["code"]).to eq("UNAUTHORIZED")
    end
  end

  it "returns USER_BLOCKED with the reason for a blocked account" do
    token = JwtService.encode(user)
    user.update!(blocked_at: Time.current, block_reason: "Spam")
    get_with("Bearer #{token}")

    expect(response).to have_http_status(:forbidden)
    expect(json["code"]).to eq("USER_BLOCKED")
    expect(json["details"].first["message"]).to eq("Spam")
  end
end
