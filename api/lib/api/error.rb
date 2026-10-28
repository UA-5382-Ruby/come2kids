module Api
    class Error < StandardError
        attr_reader :code, :status, :details
        def initialize(code, message: nil, details: {})
            entry    = ErrorCodes::CATALOG.fetch(code)
            @code    = code
            @status  = entry[:status]
            @details = details
            super(message || entry[:message])
        end
    end
end