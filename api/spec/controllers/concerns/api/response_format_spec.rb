require "rails_helper"

RSpec.describe "Api::ResponseFormat", type: :controller do
  controller do
    def show
      render_resource(User.new(id: 12, email: "person@example.com"), blueprint: Api::UserBlueprint)
    end

    def index
      render_collection(
        [ User.new(id: 12, email: "person@example.com") ],
        blueprint: Api::UserBlueprint,
        pagination: { page: 1, pageSize: 20, totalCount: 1, totalPages: 1 }
      )
    end
  end

  before do
    routes.draw do
      get "show" => "anonymous#show"
      get "index" => "anonymous#index"
    end
  end

  it "wraps a resource in the data envelope" do
    get :show

    expect(response.parsed_body.fetch("data")).to include(
      "id" => 12,
      "email" => "person@example.com"
    )
  end

  it "wraps a collection with pagination metadata" do
    get :index

    expect(response.parsed_body.fetch("data").first).to include(
      "id" => 12,
      "email" => "person@example.com"
    )
    expect(response.parsed_body).to include(
      "pagination" => {
        "page" => 1,
        "pageSize" => 20,
        "totalCount" => 1,
        "totalPages" => 1
      }
    )
  end
end
