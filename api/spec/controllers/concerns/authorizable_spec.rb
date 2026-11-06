# frozen_string_literal: true

require "rails_helper"

RSpec.describe Authorizable, type: :controller do
  controller(ApplicationController) do
    before_action :authenticate_user

    def show
      organization = Organization.find(params[:id])
      authorize organization, policy_class: MembersOnlyPolicy
      render json: { id: organization.id }
    end

    # Forgets to call `authorize` on purpose.
    def index
      render json: {}
    end
  end

  # Stands in for a real resource policy: only the owner and managers of the organization pass.
  before do
    stub_const("MembersOnlyPolicy", Class.new(ApplicationPolicy) do
      def show?
        organization_member?
      end
    end)
  end

  let(:organization) { create(:organization) }

  def perform_request(headers = {})
    request.headers.merge!(headers)
    get :show, params: { id: organization.id }
  end

  it_behaves_like "requires authentication"
  it_behaves_like "forbids access from another organization"

  context "as a regular user" do
    it_behaves_like "forbids access" do
      let(:forbidden_user) { create(:user) }
    end
  end

  context "as a moderator" do
    it_behaves_like "forbids access" do
      let(:forbidden_user) { create(:user, :moderator) }
    end
  end

  %i[owner manager].each do |role|
    it "allows the #{role} of the organization" do
      member = create(:company_member, role, organization: organization).user

      perform_request(auth_headers(member))

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["id"]).to eq(organization.id)
    end
  end

  it "returns 401 for an invalid token on an endpoint that guests may call" do
    perform_request("Authorization" => "Bearer invalid")

    expect(response).to have_http_status(:unauthorized)
    expect(response.parsed_body["code"]).to eq("UNAUTHORIZED")
  end

  it "raises when an action does not call authorize" do
    expect { get :index }.to raise_error(Pundit::AuthorizationNotPerformedError)
  end
end
