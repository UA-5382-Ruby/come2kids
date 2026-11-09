# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Users", type: :request do
  let(:user) { create(:user, first_name: "Olena", last_name: "Test", email: "original@example.com", preferred_locale: "uk") }
  let(:token) { JwtService.encode(user) }
  let(:headers) { { "Authorization" => "Bearer #{token}" } }

  describe "GET /users/me" do
    context "when user is authenticated" do
      before do
        get "/users/me", headers: headers
      end

      it "returns 200 OK status" do
        expect(response).to have_http_status(:ok)
      end

      it "returns the correct user profile data" do
        json = response.parsed_body
        expect(json["id"]).to eq(user.id)
        expect(json["email"]).to eq(user.email)
        expect(json["first_name"]).to eq("Olena")
      end
    end

    context "when authorization header is missing" do
      it "returns 401 Unauthorized" do
        get "/users/me"
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "PUT /users/me" do
    context "with valid parameters" do
      let(:update_params) do
        {
          user: {
            first_name: "UpdatedName",
            city: "Kyiv",
            preferred_locale: "en"
          }
        }
      end

      before do
        put "/users/me", params: update_params, headers: headers
      end

      it "returns 200 OK status" do
        expect(response).to have_http_status(:ok)
      end

      it "updates allowed profile fields" do
        user.reload
        expect(user.first_name).to eq("UpdatedName")
        expect(user.city).to eq("Kyiv")
        expect(user.preferred_locale).to eq("en")
      end
    end

    context "when trying to update email" do
      let(:params_with_email) do
        {
          user: {
            first_name: "UpdatedName",
            email: "new_hacked@example.com"
          }
        }
      end

      before do
        put "/users/me", params: params_with_email, headers: headers
      end

      it "returns 200 OK status" do
        expect(response).to have_http_status(:ok)
      end

      it "ignores the email change and updates other fields" do
        user.reload
        expect(user.first_name).to eq("UpdatedName")
        expect(user.email).to eq("original@example.com")
      end
    end

    context "with invalid parameters" do
      it "returns 422 Unprocessable Entity when first_name is blank" do
        put "/users/me", params: { user: { first_name: "" } }, headers: headers

        expect(response).to have_http_status(:unprocessable_entity)
        json = response.parsed_body
        expect(json["errors"]).to include("First name can't be blank")
      end

      it "returns 422 Unprocessable Entity when preferred_locale is invalid" do
        put "/users/me", params: { user: { preferred_locale: "fr" } }, headers: headers

        expect(response).to have_http_status(:unprocessable_entity)
        json = response.parsed_body
        expect(json["errors"]).to include("Preferred locale is not included in the list")
      end
    end
  end
end
