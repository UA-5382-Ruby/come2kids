# frozen_string_literal: true

# Helpers for rswag request specs (spec/requests/**).
module SwaggerHelpers
  # Sends the request of the surrounding rswag operation, exactly like `run_test!` does, for examples that
  # must wrap it, e.g. `expect { send_documented_request }.to have_enqueued_mail(...)`.
  def send_documented_request
    submit_request(RSpec.current_example.metadata)
  end

  def json
    response.parsed_body
  end
end

RSpec.configure do |config|
  config.include SwaggerHelpers, type: :request
end
