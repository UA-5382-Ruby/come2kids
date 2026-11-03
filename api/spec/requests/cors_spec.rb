require "rails_helper"

RSpec.describe "CORS", type: :request do
  let(:frontend_origin) { "http://localhost:3000" }

  it "allows the configured frontend origin" do
    get "/up", headers: { "Origin" => frontend_origin }

    expect(response).to have_http_status(:ok)
    expect(response.headers["Access-Control-Allow-Origin"]).to eq(frontend_origin)
    expect(response.headers["Access-Control-Allow-Credentials"]).to be_nil
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
