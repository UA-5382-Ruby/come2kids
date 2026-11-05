require "rails_helper"

RSpec.describe "Api::QueryParameters", type: :controller do
  controller do
    include Api::QueryParameters
    include Api::ResponseFormat

    # ПЕРЕХОПЛЮЄМО ВИНЯТОК БЛОКОМ, щоб уникнути HTML-сторінки помилки
    rescue_from Api::ApplicationError do |error|
      render json: { code: error.code, message: error.message, details: error.details }, status: :bad_request
    end

    def index
      records, pagination = paginate_collection(
        User.all,
        sortable: { createdAt: :created_at, lastName: :last_name },
        filterable: { platformRole: :platform_role }
      )

      render json: {
        data: records.as_json(only: %i[email first_name last_name platform_role]),
        pagination: pagination
      }
    end
  end

  before do
    routes.draw { get "index" => "anonymous#index" }

    User.delete_all

    User.create!(
      email: "alpha@example.com",
      password: "Password123",
      first_name: "Alpha",
      last_name: "Zephyr",
      platform_role: "user"
    )
    User.create!(
      email: "beta@example.com",
      password: "Password123",
      first_name: "Beta",
      last_name: "Anderson",
      platform_role: "moderator"
    )
    User.create!(
      email: "gamma@example.com",
      password: "Password123",
      first_name: "Gamma",
      last_name: "Baker",
      platform_role: "user"
    )
  end

  it "returns filtered, sorted records with total pagination metadata" do
    get :index, params: {
      page: "1",
      pageSize: "1",
      sort: "lastName",
      direction: "desc",
      platformRole: "user"
    }

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body).to eq(
                                      "data" => [
                                        {
                                          "email" => "alpha@example.com",
                                          "first_name" => "Alpha",
                                          "last_name" => "Zephyr",
                                          "platform_role" => "user"
                                        }
                                      ],
                                      "pagination" => {
                                        "page" => 1,
                                        "pageSize" => 1,
                                        "totalCount" => 2,
                                        "totalPages" => 2
                                      }
                                    )
  end

  it "uses defaults when pagination and sorting are omitted" do
    get :index

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body.fetch("pagination")).to include(
                                                          "page" => 1,
                                                          "pageSize" => 20,
                                                          "totalCount" => 3,
                                                          "totalPages" => 1
                                                        )
  end

  it "rejects an invalid page size" do
    get :index, params: { pageSize: "101" }

    expect(response).to have_http_status(:bad_request)
    expect(response.parsed_body["code"]).to eq("BAD_REQUEST")
    expect(response.parsed_body["details"].first["field"]).to eq("pageSize")
  end

  it "rejects an unknown sort field instead of interpolating it into SQL" do
    get :index, params: { sort: "last_name; DROP TABLE users" }

    expect(response).to have_http_status(:bad_request)
    expect(response.parsed_body.fetch("code")).to eq("BAD_REQUEST")
    expect(User.table_exists?).to be(true)
  end
end
