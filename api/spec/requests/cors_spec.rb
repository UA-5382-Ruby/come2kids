# frozen_string_literal: true

require "rails_helper"

RSpec.describe "CORS", type: :request do
  let(:frontend_origin) do
    configured_origins = ENV["FRONTEND_ORIGINS"].to_s
      .split(",")
      .filter_map(&:strip)
      .reject(&:empty?)

      configured_origins.first || "http://localhost:#{ENV.fetch("PORT", "3000")}"
  end

  it "allows the configured frontend origin" do
    get "/up", headers: { "Origin" => frontend_origin }

    expect(response).to have_http_status(:ok)
    expect(response.headers["Access-Control-Allow-Origin"]).to eq(frontend_origin)
    expect(response.headers["Access-Control-Allow-Credentials"]).to be_nil
  end

  context "without FRONTEND_ORIGINS (development defaults)", if: ENV["FRONTEND_ORIGINS"].blank? do
    api_port = ENV.fetch("PORT", "3000")
    (%w[localhost 127.0.0.1 0.0.0.0].map { |host| "http://#{host}:#{api_port}" } + [ "http://127.0.0.1:5173" ]).each do |origin|
      it "allows #{origin}" do
        get "/up", headers: { "Origin" => origin }

        expect(response.headers["Access-Control-Allow-Origin"]).to eq(origin)
      end
    end
  end

  it "does not grant access to an unconfigured origin" do
    get "/up", headers: { "Origin" => "https://untrusted.example" }

    expect(response).to have_http_status(:ok)
    expect(response.headers["Access-Control-Allow-Origin"]).to be_nil
  end

  it "handles preflight requests for allowed methods and headers" do
    process :options, "/up", headers: {
      "Origin" => frontend_origin,
      "Access-Control-Request-Method" => "POST",
      "Access-Control-Request-Headers" => "Authorization, Content-Type, Idempotency-Key"
    }

    expect(response).to have_http_status(:ok)
    expect(response.headers["Access-Control-Allow-Origin"]).to eq(frontend_origin)
    expect(response.headers["Access-Control-Allow-Methods"]).to include("POST")
    expect(response.headers["Access-Control-Allow-Headers"]).to include("Authorization")
    expect(response.headers["Access-Control-Allow-Headers"]).to include("Idempotency-Key")
  end
end
