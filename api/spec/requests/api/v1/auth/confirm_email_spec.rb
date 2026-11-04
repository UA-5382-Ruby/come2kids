require "rails_helper"

RSpec.describe "POST /api/v1/auth/confirm-email", type: :request do
  include ActiveJob::TestHelper
  include ActiveSupport::Testing::TimeHelpers

  let(:path) { "/api/v1/auth/confirm-email" }
  let(:user) { create(:user) }
  let!(:raw_token) { Tokens::EmailConfirmation.issue(user) }
  def body
    response.parsed_body
  end

  context "with a valid token" do
    it "confirms the email and returns the user" do
      post path, params: { token: raw_token }, as: :json

      expect(response).to have_http_status(:ok)
      expect(body["message"]).to be_present
      expect(body["user"]).to include("id" => user.id, "email_confirmed" => true)
      expect(user.reload).to be_email_confirmed
    end

    it "removes the token from Redis" do
      post path, params: { token: raw_token }, as: :json

      expect(Tokens::EmailConfirmation.redis.exists?(
        Tokens::EmailConfirmation.token_key(Tokens::EmailConfirmation.digest(raw_token))
      )).to be(false)
    end

    it "works right before the token expires" do
      travel_to(23.hours.from_now) do
        post path, params: { token: raw_token }, as: :json
      end

      expect(response).to have_http_status(:ok)
    end

    it "keeps the original time if the email is already confirmed" do
      confirmed_at = 2.days.ago.change(usec: 0)
      user.update!(email_confirmed_at: confirmed_at)

      post path, params: { token: raw_token }, as: :json

      expect(response).to have_http_status(:ok)
      expect(user.reload.email_confirmed_at).to eq(confirmed_at)
    end
  end

  context "with an invalid token" do
    it "rejects an unknown token" do
      post path, params: { token: "unknown-token" }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(body["code"]).to eq("TOKEN_INVALID")
      expect(user.reload).not_to be_email_confirmed
    end

    it "rejects the digest used as a token" do
      post path, params: { token: Tokens::EmailConfirmation.digest(raw_token) }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(body["code"]).to eq("TOKEN_INVALID")
    end

    it "returns 400 when the token is missing" do
      post path, params: {}, as: :json

      expect(response).to have_http_status(:bad_request)
      expect(body["code"]).to eq("PARAMETER_MISSING")
      expect(body["details"]).to include(a_hash_including("field" => "token"))
    end

    it "returns 400 when the token is blank" do
      post path, params: { token: "" }, as: :json

      expect(response).to have_http_status(:bad_request)
      expect(body["code"]).to eq("PARAMETER_MISSING")
    end
  end

  context "with an expired token" do
    it "returns TOKEN_INVALID and leaves the account unverified" do
      travel_to(25.hours.from_now) do
        post path, params: { token: raw_token }, as: :json
      end

      expect(response).to have_http_status(:unprocessable_content)
      expect(body["code"]).to eq("TOKEN_INVALID")
      expect(user.reload).not_to be_email_confirmed
    end
  end

  context "with a used token" do
    it "rejects the second use of the same token" do
      post path, params: { token: raw_token }, as: :json
      expect(response).to have_http_status(:ok)

      post path, params: { token: raw_token }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(body["code"]).to eq("TOKEN_USED")
    end
  end

  context "with a superseded token" do
    it "rejects the old token after a new one was issued" do
      new_token = Tokens::EmailConfirmation.issue(user)

      post path, params: { token: raw_token }, as: :json
      expect(body["code"]).to eq("TOKEN_INVALID")

      post path, params: { token: new_token }, as: :json
      expect(response).to have_http_status(:ok)
    end
  end

  describe "localization" do
    it "translates the error message" do
      post path, params: { token: "unknown" }, as: :json, headers: { "Accept-Language" => "en" }
      expect(body["message"]).to start_with("The token is invalid")

      post path, params: { token: "unknown" }, as: :json, headers: { "Accept-Language" => "uk" }
      expect(body["message"]).to start_with("Токен недійсний")
    end
  end

  describe "full flow: register -> email -> confirm" do
    it "confirms the account with the token from the email" do
      ActionMailer::Base.deliveries.clear

      perform_enqueued_jobs do
        post "/api/v1/auth/register", as: :json, params: {
          email: "kid@example.com", password: "Password123", first_name: "Ira", last_name: "Koval"
        }
      end
      expect(response).to have_http_status(:created)

      token = ActionMailer::Base.deliveries.last.text_part.decoded[/token=([\w-]+)/, 1]
      post path, params: { token: token }, as: :json

      expect(response).to have_http_status(:ok)
      expect(User.find_by!(email: "kid@example.com")).to be_email_confirmed
    end
  end
end
