require "test_helper"

class FilteringTest < ActionDispatch::IntegrationTest
    test "range filter is inclusive and total reflects the filtered scope" do
        get "/orders", params: { filter: { created_at_from: "2025-01-01T00:00:00Z",
                                        created_at_to:   "2025-01-31T23:59:59Z" } }
        assert_response :ok
        assert_equal Order.where(created_at: Time.utc(2025, 1, 1)..Time.utc(2025, 1, 31, 23, 59, 59)).count,
                    response.parsed_body.dig("meta", "total")
    end

    test "open-ended range (only _from) works" do
        get "/orders", params: { filter: { amount_minor_from: "1000" } }
        assert_response :ok
    end

    test "unknown filter key returns 400 with allowed keys" do
        get "/orders", params: { filter: { secret_column: "x" } }
        assert_response :bad_request
        body = response.parsed_body
        assert_equal "invalid_parameter", body["code"]
        assert_includes body.dig("details", "unknown"), "secret_column"
    end

    test "malformed timestamp returns 400" do
        get "/orders", params: { filter: { created_at_from: "yesterday" } }
        assert_response :bad_request
        assert_equal "filter[created_at_from]", response.parsed_body.dig("details", "param")
    end

    test "timestamp without timezone returns 400" do
        get "/orders", params: { filter: { created_at_from: "2025-01-01T00:00:00" } }
        assert_response :bad_request
    end

    test "non-integer amount returns 400" do
        get "/orders", params: { filter: { amount_minor_from: "12.5" } }
        assert_response :bad_request
    end

    test "from greater than to returns 400" do
        get "/orders", params: { filter: { created_at_from: "2025-02-01T00:00:00Z",
                                        created_at_to:   "2025-01-01T00:00:00Z" } }
        assert_response :bad_request
    end

    test "nested object value returns 400" do
        get "/orders", params: { filter: { status: { foo: "bar" } } }
        assert_response :bad_request
    end
end