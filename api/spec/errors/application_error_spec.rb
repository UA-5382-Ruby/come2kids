require "rails_helper"

RSpec.describe Api::ApplicationError do
  describe "status lookup" do
    it "uses the status registered for the error code" do
      error = described_class.new(
        code: Api::ErrorCodes::NOT_FOUND,
        message: "Event was not found."
      )

      expect(error.status).to eq(:not_found)
      expect(error.details).to eq([])
    end
  end

  it "allows a domain error to provide details and an explicit status" do
    error = described_class.new(
      code: Api::ErrorCodes::CONFLICT,
      message: "The event cannot be changed.",
      details: [ { field: "status", message: "is already published" } ],
      status: :unprocessable_entity
    )

    expect(error.message).to eq("The event cannot be changed.")
    expect(error.details).to eq([ { field: "status", message: "is already published" } ])
    expect(error.status).to eq(:unprocessable_entity)
  end
end
