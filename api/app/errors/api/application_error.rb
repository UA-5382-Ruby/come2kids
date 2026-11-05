module Api
  class ApplicationError < StandardError
    attr_reader :code, :details, :status

    def initialize(code:, message:, details: [], status: nil)
      @code = code
      @details = details
      @status = status || ErrorCodes::HTTP_STATUSES.fetch(code)
      super(message)
    end
  end
end
