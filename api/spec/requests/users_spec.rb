require "rails_helper"

RSpec.describe "Users", type: :request do
  let(:user) { create(:user, first_name: "Olena", last_name: "Test", email: "original@example.com", preferred_locale: "uk") }
  let(:token) { JwtService.encode(user) }
  let(:headers) { { "Authorization" => "Bearer #{token}" } }

  describe "GET /users/me" do
    context "when user is authenticated" do
      it "returns the user profile with 200 OK" do
        get "/users/me", headers: headers

        expect(response).to have_http_status(:ok)
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

      it "updates allowed profile fields" do
        put "/users/me", params: update_params, headers: headers

        expect(response).to have_http_status(:ok)
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

      it "ignores the email change and keeps the original value" do
        expect do
          put "/users/me", params: params_with_email, headers: headers
        end.not_to change { user.reload.email }

        expect(response).to have_http_status(:ok)
        expect(user.reload.first_name).to eq("UpdatedName")
        expect(user.reload.email).to eq("original@example.com")
      end
    end

    context "with invalid parameters" do
      it "returns 422 Unprocessable Entity when first_name is blank" do
        put "/users/me", params: { user: { first_name: "" } }, headers: headers

        expect(response).to have_http_status(:unprocessable_entity)
        json = response.parsed_body
        expect(json).to have_key("errors")
        expect(json["errors"]).to include("First name can't be blank")
      end

      it "returns 422 Unprocessable Entity when preferred_locale is invalid" do
        put "/users/me", params: { user: { preferred_locale: "fr" } }, headers: headers

        expect(response).to have_http_status(:unprocessable_entity)
        json = response.parsed_body
        expect(json).to have_key("errors")
        expect(json["errors"]).to include("Preferred locale is not included in the list")
      end
    end
  end
end