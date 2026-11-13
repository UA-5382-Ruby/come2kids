# frozen_string_literal: true

require "rails_helper"

RSpec.describe "POST /api/v1/auth/forgot-password", type: :request do
  let(:path) { "/api/v1/auth/forgot-password" }
  let(:user) { create(:user, email: "user@example.com", first_name: "Olena") }

  before do
    ActiveJob::Base.queue_adapter = :test
    Tokens::PasswordReset.redis.flushdb
  end

  it "sends a reset email and returns a generic success message for an existing user" do
    expect {
      post path, params: { email: user.email }, as: :json
    }.to have_enqueued_mail(UserMailer, :password_reset) # ✅ Спрощена перевірка

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body["message"]).to eq(I18n.t("auth.forgot_password_sent"))
  end

  it "prevents email enumeration by returning the same response for a non-existent email" do
    expect {
      post path, params: { email: "nobody@example.com" }, as: :json
    }.not_to have_enqueued_mail(UserMailer, :password_reset)

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body["message"]).to eq(I18n.t("auth.forgot_password_sent"))
  end

  it "prevents email enumeration for a blocked user" do
    user.update!(blocked_at: Time.current, block_reason: "Violation")

    expect {
      post path, params: { email: user.email }, as: :json
    }.not_to have_enqueued_mail(UserMailer, :password_reset)

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body["message"]).to eq(I18n.t("auth.forgot_password_sent"))
  end

  it "enforces a cooldown period to prevent spam" do
    post path, params: { email: user.email }, as: :json
    expect(response).to have_http_status(:ok)

    expect {
      post path, params: { email: user.email }, as: :json
    }.not_to have_enqueued_mail(UserMailer, :password_reset)

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body["message"]).to eq(I18n.t("auth.forgot_password_sent"))
  end

  it "returns 400 Bad Request when email is missing" do
    post path, params: {}, as: :json

    expect(response).to have_http_status(:bad_request)
    expect(response.parsed_body["code"]).to eq("PARAMETER_MISSING")
  end

  it "returns 400 Bad Request when email is blank" do
    post path, params: { email: "   " }, as: :json

    expect(response).to have_http_status(:bad_request)
    expect(response.parsed_body["code"]).to eq("PARAMETER_MISSING")
  end

  it "translates the response message based on Accept-Language header" do
    post path, params: { email: "nobody@example.com" }, as: :json, headers: { "Accept-Language" => "uk" }

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body["message"]).to eq("Якщо акаунт з такою електронною адресою існує, ми надіслали посилання для скидання пароля.")
  end
end
