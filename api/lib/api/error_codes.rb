module Api
    module ErrorCodes
        CATALOG = {
            bad_request:       { status: 400, message: "Bad request" },
            invalid_parameter: { status: 400, message: "Invalid query parameter" },
            unauthorized:      { status: 401, message: "Authentication required" },
            forbidden:         { status: 403, message: "You are not allowed to perform this action" },
            not_found:         { status: 404, message: "Resource not found" },
            conflict:          { status: 409, message: "Conflict" },
            validation_failed: { status: 422, message: "Validation failed" },
            internal_error:    { status: 500, message: "Internal server error" }
        }.freeze
    end
end