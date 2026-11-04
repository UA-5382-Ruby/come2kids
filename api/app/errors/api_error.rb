class ApiError < StandardError
  attr_reader :code, :status, :details

  def initialize(code, status: :unprocessable_entity, details: [])
    @code = code.to_s.upcase
    @status = status
    @details = details
    super(@code)
  end
end
