# frozen_string_literal: true

require "rails_helper"

RSpec.describe "CORS", type: :request do
  around do |example|
    original_origins = ENV["CORS_ALLOWED_ORIGINS"]
    ENV["CORS_ALLOWED_ORIGINS"] = "http://localhost:3000"
    example.run
  ensure
    ENV["CORS_ALLOWED_ORIGINS"] = original_origins
  end

  it "allows requests from a configured frontend origin" do
    get "/up", headers: { "Origin" => "http://localhost:3000" }

    expect(response).to have_http_status(:ok)
    expect(response.headers["Access-Control-Allow-Origin"]).to eq("http://localhost:3000")
  end

  it "does not allow requests from an unconfigured origin" do
    get "/up", headers: { "Origin" => "https://untrusted.example.com" }

    expect(response).to have_http_status(:ok)
    expect(response.headers).not_to have_key("Access-Control-Allow-Origin")
  end

  it "handles preflight requests for a configured frontend origin" do
    options "/up", headers: {
      "Origin" => "http://localhost:3000",
      "Access-Control-Request-Method" => "GET"
    }

    expect(response).to have_http_status(:ok)
    expect(response.headers["Access-Control-Allow-Origin"]).to eq("http://localhost:3000")
    expect(response.headers["Access-Control-Allow-Methods"]).to include("GET")
  end
end
