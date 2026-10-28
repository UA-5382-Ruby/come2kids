require "test_helper"

class ErrorHandlingTest < ActionDispatch::IntegrationTest
    test "unknown route returns unified 404" do
        get "/does-not-exist"
        assert_response :not_found
        body = response.parsed_body
        assert_equal %w[code details message], body.keys.sort
        assert_equal "not_found", body["code"]
    end

    test "unexpected error returns 500 without leaking internals" do
        ErrorsController.stub_any_instance(:not_found, -> { raise "boom" }) do # or use a test-only route/controller
            get "/does-not-exist"
        end
        assert_response :internal_server_error
        assert_equal "internal_error", response.parsed_body["code"]
        assert_no_match(/boom/, response.body)
    end
end