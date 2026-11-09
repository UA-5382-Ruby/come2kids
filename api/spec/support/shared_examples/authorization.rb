# frozen_string_literal: true

# Reusable authorization examples for endpoint specs (US-2.4).
#
# The including spec defines how to call the endpoint, passing the given headers through:
#
#   def perform_request(headers = {})
#     put api_v1_event_path(event), params: { title: "New" }, headers: headers, as: :json
#   end
#
#   it_behaves_like "requires authentication"
#   it_behaves_like "forbids access" do
#     let(:forbidden_user) { create(:user) }
#   end
#   it_behaves_like "forbids access from another organization"

RSpec.shared_examples "requires authentication" do
  it "returns 401 UNAUTHORIZED without an access token" do
    perform_request

    expect(response).to have_http_status(:unauthorized)
    expect(response.parsed_body["code"]).to eq("UNAUTHORIZED")
  end
end

# Requires `let(:forbidden_user)`: an authenticated user who lacks the permission.
RSpec.shared_examples "forbids access" do
  it "returns 403 FORBIDDEN for an authenticated user without the permission" do
    perform_request(auth_headers(forbidden_user))

    expect(response).to have_http_status(:forbidden)
    expect(response.parsed_body["code"]).to eq("FORBIDDEN")
  end
end

# The owner and a manager of a different organization must not reach this organization's resources.
RSpec.shared_examples "forbids access from another organization" do
  let(:other_organization) { create(:organization) }

  %i[owner manager].each do |role|
    it "returns 403 FORBIDDEN for the #{role} of another organization" do
      outsider = create(:company_member, role, organization: other_organization).user

      perform_request(auth_headers(outsider))

      expect(response).to have_http_status(:forbidden)
      expect(response.parsed_body["code"]).to eq("FORBIDDEN")
    end
  end
end
