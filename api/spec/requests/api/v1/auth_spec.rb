require "rails_helper"

RSpec.describe "Api::V1::Auth", type: :request do
  let(:user) { create(:user) }
  let(:password) { "password1" }
  let(:headers) { { "X-Requested-With" => "XMLHttpRequest" } }
  let(:json) { response.parsed_body }
  let(:set_cookie) { Array(response.headers["Set-Cookie"]).join("\n") }

  # Rate limits live in Rails.cache; start every example with a clean counter.
  before { Rails.cache.clear }

  def login(email: user.email, password: self.password)
    post api_v1_auth_login_path, params: { email: email, password: password }, as: :json, headers: headers
  end

  def refresh(request_headers = headers)
    post api_v1_auth_refresh_path, headers: request_headers
  end

  def logout
    post api_v1_auth_logout_path, headers: headers
  end

  describe "POST /api/v1/auth/login" do
    context "with valid credentials" do
      before { login }

      it "returns a Bearer access token for the user" do
        expect(response).to have_http_status(:ok)
        expect(json).to include("token_type" => "Bearer", "expires_in" => JwtService::ACCESS_TTL.to_i)
        expect(JwtService.decode(json["access_token"])["sub"]).to eq(user.id.to_s)
      end

      it "does not expose the refresh token in the body" do
        expect(json).not_to have_key("refresh_token")
      end

      it "sets the refresh token as an HttpOnly, SameSite=Strict cookie on /api/v1/auth" do
        expect(set_cookie).to match(/refresh_token=.+httponly/im)
          .and match(/samesite=strict/i)
          .and match(%r{path=/api/v1/auth}i)
      end

      it "stores one active refresh token" do
        expect(user.refresh_tokens.active.count).to eq(1)
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
      post api_v1_auth_login_path, params: {}, as: :json, headers: headers

      expect(response).to have_http_status(:unprocessable_content)
      expect(json["code"]).to eq("VALIDATION_ERROR")
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

    context "when the account is soft-deleted" do
      let(:user) { create(:user, :deleted) }

      it "returns INVALID_CREDENTIALS" do
        login

        expect(response).to have_http_status(:unauthorized)
        expect(json["code"]).to eq("INVALID_CREDENTIALS")
      end
    end

    context "when the user is blocked" do
      let(:user) { create(:user, :blocked) }

      before { login }

      it "returns USER_BLOCKED with the reason" do
        expect(response).to have_http_status(:forbidden)
        expect(json["code"]).to eq("USER_BLOCKED")
        expect(json["details"].first["message"]).to eq("Spam")
      end

      it "does not issue a refresh token" do
        expect(user.refresh_tokens).to be_empty
      end
    end

    it "is rate limited after five attempts" do
      5.times { login(password: "wrong-pass1") }
      login

      expect(response).to have_http_status(:too_many_requests)
      expect(json["code"]).to eq("TOO_MANY_REQUESTS")
    end
  end

  describe "POST /api/v1/auth/refresh" do
    context "after login" do
      before { login }

      it "returns a new access token and rotates the refresh token" do
        old_token = user.refresh_tokens.sole
        refresh

        expect(response).to have_http_status(:ok)
        expect(JwtService.decode(json["access_token"])["sub"]).to eq(user.id.to_s)
        expect(old_token.reload).to be_revoked
      end

      it "keeps exactly one active refresh token" do
        refresh

        expect(user.refresh_tokens.active.count).to eq(1)
      end

      it "revokes every session when a rotated token is reused" do
        stolen = cookies[:refresh_token]
        refresh
        cookies[:refresh_token] = stolen
        refresh

        expect(response).to have_http_status(:unauthorized)
        expect(json["code"]).to eq("INVALID_REFRESH_TOKEN")
        expect(user.refresh_tokens.active).to be_empty
      end

      it "rejects an expired refresh token" do
        user.refresh_tokens.sole.update!(expires_at: 1.second.ago)
        refresh

        expect(response).to have_http_status(:unauthorized)
        expect(json["code"]).to eq("INVALID_REFRESH_TOKEN")
      end

      it "requires the X-Requested-With header" do
        refresh({})

        expect(response).to have_http_status(:forbidden)
        expect(json["code"]).to eq("CSRF_HEADER_MISSING")
      end

      it "returns USER_BLOCKED and revokes tokens when the user was blocked meanwhile" do
        user.update!(blocked_at: Time.current, block_reason: "Fraud")
        refresh

        expect(response).to have_http_status(:forbidden)
        expect(json["code"]).to eq("USER_BLOCKED")
        expect(user.refresh_tokens.active).to be_empty
      end

      it "rejects the token when the account was deleted meanwhile" do
        user.update!(deleted_at: Time.current)
        refresh

        expect(response).to have_http_status(:unauthorized)
        expect(user.refresh_tokens.active).to be_empty
      end
    end

    it "rejects a request without a cookie" do
      refresh

      expect(response).to have_http_status(:unauthorized)
      expect(json["code"]).to eq("INVALID_REFRESH_TOKEN")
    end
  end

  describe "POST /api/v1/auth/logout" do
    context "after login" do
      before { login }

      it "revokes the refresh token" do
        logout

        expect(response).to have_http_status(:no_content)
        expect(user.refresh_tokens.active).to be_empty
      end

      it "makes the refresh token unusable" do
        logout
        refresh

        expect(response).to have_http_status(:unauthorized)
      end
    end

    it "succeeds without a cookie" do
      logout

      expect(response).to have_http_status(:no_content)
    end
  end
end
