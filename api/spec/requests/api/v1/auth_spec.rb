require "rails_helper"

RSpec.describe "Api::V1::Auth", type: :request do
  let(:user) { create(:user) }
  let(:password) { "Password123" }
  let(:json) { response.parsed_body }

  # Rate limits live in Rails.cache; start every example with a clean counter.
  before { Rails.cache.clear }

  def login(email: user.email, password: self.password)
    post api_v1_auth_login_path, params: { email: email, password: password }, as: :json
  end

  describe "POST /api/v1/auth/login" do
    context "with valid credentials" do
      before { login }

      it "returns a Bearer access token for the user" do
        expect(response).to have_http_status(:ok)
        expect(json).to include("token_type" => "Bearer", "expires_in" => JwtService::ACCESS_TTL.to_i)
        expect(JwtService.decode(json["access_token"])["sub"]).to eq(user.id.to_s)
      end

      it "returns no refresh token and sets no cookie" do
        expect(json.keys).to contain_exactly("access_token", "token_type", "expires_in")
        expect(response.headers["Set-Cookie"]).to be_blank
      end
    end

    it "accepts the email in any case" do
      login(email: user.email.upcase)

      expect(response).to have_http_status(:ok)
    end

    it "rejects a wrong password" do
      login(password: "wrong-pass1")

      expect(response).to have_http_status(:unauthorized)
      expect(json["code"]).to eq("INVALID_CREDENTIALS")
    end

    it "gives the same error for an unknown email" do
      login(email: "nobody@example.com")

      expect(response).to have_http_status(:unauthorized)
      expect(json["code"]).to eq("INVALID_CREDENTIALS")
    end

    it "requires email and password" do
      post api_v1_auth_login_path, params: {}, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(json["code"]).to eq("VALIDATION_FAILED")
      expect(json["details"].pluck("field")).to eq(%w[email password])
    end

    context "when the email is not confirmed" do
      let(:user) { create(:user, :unconfirmed) }

      it "returns EMAIL_NOT_CONFIRMED" do
        login

        expect(response).to have_http_status(:forbidden)
        expect(json["code"]).to eq("EMAIL_NOT_CONFIRMED")
      end
    end

    { "soft-deleted" => { deleted_at: Time.current }, "inactive" => { is_active: false } }.each do |state, attributes|
      context "when the account is #{state}" do
        let(:user) { create(:user, **attributes) }

        it "returns INVALID_CREDENTIALS" do
          login

          expect(response).to have_http_status(:unauthorized)
          expect(json["code"]).to eq("INVALID_CREDENTIALS")
        end
      end
    end

    context "when the user is blocked" do
      let(:user) { create(:user, :blocked) }

      it "returns USER_BLOCKED with the reason and no access token" do
        login

        expect(response).to have_http_status(:forbidden)
        expect(json["code"]).to eq("USER_BLOCKED")
        expect(json["details"].first["message"]).to eq("Spam")
        expect(json).not_to have_key("access_token")
      end
    end

    it "is rate limited after five attempts" do
      5.times { login(password: "wrong-pass1") }
      login

      expect(response).to have_http_status(:too_many_requests)
      expect(json["code"]).to eq("TOO_MANY_REQUESTS")
    end

    it "is rate limited per IP even when the email changes" do
      20.times { |i| login(email: "probe#{i}@example.com") }
      login

      expect(response).to have_http_status(:too_many_requests)
    end
  end

  it "has no refresh or logout endpoints" do
    expect(Rails.application.routes.url_helpers).not_to respond_to(:api_v1_auth_refresh_path)
    expect(Rails.application.routes.url_helpers).not_to respond_to(:api_v1_auth_logout_path)
  end
end
