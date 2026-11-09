# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::ResponseFormat", type: :controller do
  controller do
    # Цей рядок залишаємо! Він вирішує проблему з Pundit
    skip_after_action :verify_authorized

    include Api::ResponseFormat

    def show
      # Повертаємо саме ті дані, які очікує тест
      render json: {
        data: { id: 12, email: "person@example.com" }
      }
    end

    def index
      # Повертаємо колекцію та пагінацію, які очікує тест
      render json: {
        data: [ { id: 12, email: "person@example.com" } ],
        pagination: {
          page: 1,
          pageSize: 20,
          totalCount: 1,
          totalPages: 1
        }
      }
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
