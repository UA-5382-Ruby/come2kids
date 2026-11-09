# frozen_string_literal: true

require "rails_helper"

RSpec.describe "POST /api/v1/auth/resend-confirmation", type: :request do
  include ActiveJob::TestHelper
  include ActiveSupport::Testing::TimeHelpers

  let(:path) { "/api/v1/auth/resend-confirmation" }

  def body
    response.parsed_body
  end

  def last_mail_token
    ActionMailer::Base.deliveries.last.text_part.decoded[/token=([\w-]+)/, 1]
  end

  context "with an unverified user" do
    let!(:user) { create(:user, :unconfirmed, email: "mom@example.com") }

    it "sends a new confirmation email" do
      expect { post path, params: { email: user.email }, as: :json }
        .to have_enqueued_mail(UserMailer, :confirmation)

      expect(response).to have_http_status(:ok)
      expect(body["message"]).to be_present
    end

    it "finds the user regardless of email case and spaces" do
      expect { post path, params: { email: "  MOM@example.com " }, as: :json }
        .to have_enqueued_mail(UserMailer, :confirmation)
    end

    it "sends an email with a token that confirms the account" do
      ActionMailer::Base.deliveries.clear
      perform_enqueued_jobs { post path, params: { email: user.email }, as: :json }

      post "/api/v1/auth/confirm-email", params: { token: last_mail_token }, as: :json

      expect(response).to have_http_status(:ok)
      expect(user.reload).to be_email_confirmed
    end

    it "makes the link from the previous email stop working" do
      old_token = Tokens::EmailConfirmation.issue(user)

      post path, params: { email: user.email }, as: :json
      post "/api/v1/auth/confirm-email", params: { token: old_token }, as: :json

      expect(response.parsed_body["code"]).to eq("TOKEN_INVALID")
    end
  end

  describe "rate limiting (cooldown)" do
    let!(:user) { create(:user, :unconfirmed) }

    it "ignores a repeated request within the cooldown" do
      Tokens::EmailConfirmation.acquire_cooldown(user)

      expect { post path, params: { email: user.email }, as: :json }
        .not_to have_enqueued_mail(UserMailer, :confirmation)
      expect(response).to have_http_status(:ok)
    end

    it "does not allow a second resend right away" do
      post path, params: { email: user.email }, as: :json

      expect { post path, params: { email: user.email }, as: :json }
        .not_to have_enqueued_mail(UserMailer, :confirmation)
    end

    it "does not allow a resend right after registration" do
      post "/api/v1/auth/register", as: :json, params: {
        email: "new@example.com", password: "Password123", first_name: "Ira", last_name: "Koval"
      }

      expect { post path, params: { email: "new@example.com" }, as: :json }
        .not_to have_enqueued_mail(UserMailer, :confirmation)
    end

    it "allows a resend after the cooldown" do
      Tokens::EmailConfirmation.acquire_cooldown(user)

      travel_to(61.seconds.from_now) do
        expect { post path, params: { email: user.email }, as: :json }
          .to have_enqueued_mail(UserMailer, :confirmation)
      end
    end
  end

  describe "no account enumeration" do
    it "sends nothing and answers the same for an unknown email" do
      expect { post path, params: { email: "nobody@example.com" }, as: :json }
        .not_to have_enqueued_mail(UserMailer, :confirmation)

      expect(response).to have_http_status(:ok)
      expect(body["message"]).to be_present
    end

    it "sends nothing for an already confirmed user" do
      user = create(:user, :confirmed)

      expect { post path, params: { email: user.email }, as: :json }
        .not_to have_enqueued_mail(UserMailer, :confirmation)
      expect(response).to have_http_status(:ok)
    end

    it "sends nothing for a blocked user" do
      user = create(:user, :blocked)

      expect { post path, params: { email: user.email }, as: :json }
        .not_to have_enqueued_mail(UserMailer, :confirmation)
      expect(response).to have_http_status(:ok)
    end

    it "returns identical responses for existing, unknown, confirmed and throttled emails" do
      unverified = create(:user, :unconfirmed)
      confirmed = create(:user, :confirmed) # Цей залишаємо як є!
      throttled = create(:user, :unconfirmed)
      Tokens::EmailConfirmation.acquire_cooldown(throttled)

      responses = [ unverified.email, "nobody@example.com", confirmed.email, throttled.email ].map do |email|
        post path, params: { email: email }, as: :json
        [ response.status, response.parsed_body ]
      end

      expect(responses.uniq.size).to eq(1)
    end
  end

  context "with invalid input" do
    it "returns 400 when the email is missing" do
      post path, params: {}, as: :json

      expect(response).to have_http_status(:bad_request)
      expect(body["code"]).to eq("PARAMETER_MISSING")
      expect(body["details"]).to include(a_hash_including("field" => "email"))
    end

    it "returns 400 when the email is blank" do
      post path, params: { email: "" }, as: :json

      expect(response).to have_http_status(:bad_request)
    end
  end

  describe "localization" do
    it "translates the response message" do
      post path, params: { email: "nobody@example.com" }, as: :json, headers: { "Accept-Language" => "en" }
      expect(body["message"]).to start_with("If an account")

      post path, params: { email: "nobody@example.com" }, as: :json, headers: { "Accept-Language" => "uk" }
      expect(body["message"]).to start_with("Якщо акаунт")
    end
  end
end
