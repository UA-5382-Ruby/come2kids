require "rails_helper"

RSpec.describe "POST /api/v1/auth/register", type: :request do
  include ActiveJob::TestHelper

  let(:path) { "/api/v1/auth/register" }
  let(:valid_params) do
    {
      email: "mom@example.com",
      password: "Password123",
      first_name: "Olena",
      last_name: "Shevchenko"
    }
  end
  def body
    response.parsed_body
  end

  def error_details(field, error)
    body["details"].select { |detail| detail["field"] == field && detail["error"] == error }
  end

  context "with valid data" do
    it "creates an unverified user and returns 201" do
      expect { post path, params: valid_params, as: :json }.to change(User, :count).by(1)

      expect(response).to have_http_status(:created)
      expect(body["message"]).to be_present
      expect(body["user"]).to include(
                                "email" => "mom@example.com",
                                "first_name" => "Olena",
                                "last_name" => "Shevchenko",
                                "preferred_locale" => "uk",
                                "email_confirmed" => false
                              )
      expect(User.find_by(email: "mom@example.com")).not_to be_email_confirmed
    end

    it "never returns password data" do
      post path, params: valid_params, as: :json

      expect(body["user"].keys).not_to include("password", "password_digest", "password_confirmation")
      expect(response.body).not_to include("Password123")
    end

    it "stores a confirmation token in Redis for 24 hours" do
      post path, params: valid_params, as: :json

      user = User.find_by!(email: "mom@example.com")
      ttl = Tokens::EmailConfirmation.redis.ttl(Tokens::EmailConfirmation.user_key(user.id))
      expect(ttl).to be_within(5).of(24.hours.to_i)
    end

    it "enqueues the confirmation email" do
      expect { post path, params: valid_params, as: :json }
        .to have_enqueued_mail(UserMailer, :confirmation)
    end

    it "keeps only the digest of the token in Redis, never the raw token" do
      ActionMailer::Base.deliveries.clear
      perform_enqueued_jobs { post path, params: valid_params, as: :json }

      raw_token = ActionMailer::Base.deliveries.last.text_part.decoded[/token=([\w-]+)/, 1]
      keys = Tokens::EmailConfirmation.redis.keys

      expect(raw_token).to be_present
      expect(keys).to include("email_confirmation:token:#{Digest::SHA256.hexdigest(raw_token)}")
      expect(keys).not_to include(a_string_including(raw_token))
    end

    it "normalizes the email" do
      post path, params: valid_params.merge(email: "  Mom@Example.COM "), as: :json

      expect(response).to have_http_status(:created)
      expect(User.last.email).to eq("mom@example.com")
    end

    it "saves the language of the request as the preferred language" do
      post path, params: valid_params, as: :json, headers: { "Accept-Language" => "en" }

      expect(body["user"]["preferred_locale"]).to eq("en")
    end

    it "prefers an explicit preferred_locale over the request language" do
      post path, params: valid_params.merge(preferred_locale: "en"), as: :json

      expect(body["user"]["preferred_locale"]).to eq("en")
    end

    it "ignores attributes that must not be set by the client" do
      post path, params: valid_params.merge(platform_role: "moderator", email_confirmed_at: Time.current), as: :json

      user = User.find_by!(email: "mom@example.com")
      expect(user.platform_role).to eq("user")
      expect(user).not_to be_email_confirmed
    end
  end

  context "with a duplicate email" do
    before { create(:user, email: "mom@example.com") }

    it "returns 422 with the taken error on email" do
      expect { post path, params: valid_params, as: :json }.not_to change(User, :count)

      expect(response).to have_http_status(:unprocessable_content)
      expect(body["code"]).to eq("VALIDATION_ERROR")
      expect(error_details("email", "taken")).not_to be_empty
    end

    it "treats the email as case-insensitive" do
      post path, params: valid_params.merge(email: "MOM@EXAMPLE.COM"), as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(error_details("email", "taken")).not_to be_empty
    end

    it "does not send an email" do
      expect { post path, params: valid_params, as: :json }
        .not_to have_enqueued_mail(UserMailer, :confirmation)
    end
  end

  context "with a weak password" do
    {
      "fewer than 8 characters" => "Ab1",
      "no digit" => "PasswordOnly",
      "no letter" => "12345678"
    }.each do |label, password|
      it "rejects a password with #{label}" do
        expect { post path, params: valid_params.merge(password: password), as: :json }
          .not_to change(User, :count)

        expect(response).to have_http_status(:unprocessable_content)
        expect(error_details("password", "complexity")).not_to be_empty
      end
    end

    it "accepts exactly 8 characters with a letter and a digit" do
      post path, params: valid_params.merge(password: "abcdefg1"), as: :json

      expect(response).to have_http_status(:created)
    end
  end

  context "with invalid data" do
    it "rejects a mismatched password confirmation" do
      post path, params: valid_params.merge(password_confirmation: "Different123"), as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(error_details("password_confirmation", "confirmation")).not_to be_empty
    end

    it "rejects an invalid email format" do
      post path, params: valid_params.merge(email: "not-an-email"), as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(error_details("email", "invalid")).not_to be_empty
    end

    it "rejects an unsupported preferred_locale" do
      post path, params: valid_params.merge(preferred_locale: "de"), as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(error_details("preferred_locale", "inclusion")).not_to be_empty
    end

    it "rejects names longer than 100 characters" do
      post path, params: valid_params.merge(first_name: "a" * 101), as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(error_details("first_name", "too_long")).not_to be_empty
    end

    it "lists every missing required field" do
      post path, params: {}, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      fields = body["details"].map { |detail| detail["field"] }
      expect(fields).to include("email", "password", "first_name", "last_name")
    end

    it "does not create a user or a token when validation fails" do
      expect { post path, params: valid_params.merge(password: "weak"), as: :json }
        .not_to change { [ User.count, Tokens::EmailConfirmation.redis.keys.size ] }
    end
  end

  describe "localization" do
    it "uses the same error code in every language" do
      post path, params: {}, as: :json, headers: { "Accept-Language" => "uk" }
      uk_code = body["code"]
      post path, params: {}, as: :json, headers: { "Accept-Language" => "en" }

      expect(body["code"]).to eq(uk_code)
      expect(body["code"]).to eq("VALIDATION_ERROR")
    end

    it "translates the message by Accept-Language" do
      post path, params: {}, as: :json, headers: { "Accept-Language" => "en-US,en;q=0.9" }
      expect(body["message"]).to eq("Validation failed.")

      post path, params: {}, as: :json, headers: { "Accept-Language" => "uk" }
      expect(body["message"]).to eq("Дані не пройшли перевірку.")
    end

    it "uses Ukrainian when no language is specified" do
      post path, params: {}, as: :json

      expect(body["message"]).to eq("Дані не пройшли перевірку.")
    end

    it "lets the locale parameter override the header" do
      post "#{path}?locale=en", params: {}, as: :json, headers: { "Accept-Language" => "uk" }

      expect(body["message"]).to eq("Validation failed.")
    end

    it "falls back to Ukrainian for an unsupported language" do
      post path, params: {}, as: :json, headers: { "Accept-Language" => "fr-FR,fr;q=0.9" }

      expect(body["message"]).to eq("Дані не пройшли перевірку.")
    end

    it "translates the password complexity message" do
      post path, params: valid_params.merge(password: "weak"), as: :json, headers: { "Accept-Language" => "en" }

      message = body["details"].find { |detail| detail["error"] == "complexity" }["message"]
      expect(message).to include("at least 8 characters")
    end
  end
end
