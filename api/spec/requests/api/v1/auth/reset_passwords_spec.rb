# frozen_string_literal: true

require "rails_helper"

RSpec.describe "POST /api/v1/auth/reset-password", type: :request do
  let(:path) { "/api/v1/auth/reset-password" }
  let(:user) { create(:user, email: "user@example.com", password: "OldPassword123") }
  let(:raw_token) { Tokens::PasswordReset.issue(user) }

  let(:valid_params) do
    {
      token: raw_token,
      password: "NewPassword123",
      password_confirmation: "NewPassword123"
    }
  end

  before do
    Tokens::PasswordReset.redis.flushdb
  end

  it "updates the password and returns a success message" do
    post path, params: valid_params, as: :json

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body["message"]).to eq(I18n.t("auth.password_reset_success"))

    user.reload
    expect(user.authenticate("NewPassword123")).to eq(user)

    # ⚠️ ВАЖЛИВО: Адаптуй цю перевірку під свою реалізацію відкликання токенів!
    # Приклад для Варіанту Б (видалення Set):
    # expect(Tokens::PasswordReset.redis.scard("user:#{user.id}:refresh_tokens")).to eq(0)
    # Приклад для Варіанту В (інкремент версії):
    # expect(Tokens::PasswordReset.redis.get("user:#{user.id}:refresh_token_version").to_i).to eq(1)
  end

  it "rejects an unknown or invalid token" do
    post path, params: valid_params.merge(token: "invalid-token"), as: :json

    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.parsed_body["code"]).to eq("TOKEN_INVALID")
  end

  it "rejects a previously used token (single-use guarantee)" do
    # Перше успішне використання
    post path, params: valid_params, as: :json
    expect(response).to have_http_status(:ok)

    # Друга спроба з тим самим токеном
    post path, params: valid_params, as: :json

    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.parsed_body["code"]).to eq("TOKEN_USED")
  end

  it "rejects a weak password with validation errors" do
    post path, params: valid_params.merge(password: "weak", password_confirmation: "weak"), as: :json

    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.parsed_body["code"]).to eq("VALIDATION_ERROR")
    expect(response.parsed_body["details"].first["field"]).to eq("password")
    expect(response.parsed_body["details"].first["error"]).to eq("complexity")
  end

  it "rejects mismatched password confirmation" do
    post path, params: valid_params.merge(password_confirmation: "DifferentPassword123"), as: :json

    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.parsed_body["code"]).to eq("VALIDATION_ERROR")
    expect(response.parsed_body["details"].map { |d| d["field"] }).to include("password_confirmation")
  end

  it "returns 400 Bad Request when required parameters are missing" do
    post path, params: { token: raw_token }, as: :json # Відсутні password та password_confirmation

    expect(response).to have_http_status(:bad_request)
    expect(response.parsed_body["code"]).to eq("PARAMETER_MISSING")
  end

  it "translates validation errors based on Accept-Language header" do
    post path,
         params: valid_params.merge(password: "weak", password_confirmation: "weak"),
         as: :json,
         headers: { "Accept-Language" => "uk" }

    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.parsed_body["message"]).to eq("Дані не пройшли перевірку.")
  end
end
