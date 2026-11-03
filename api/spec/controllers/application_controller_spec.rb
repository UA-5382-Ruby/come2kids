require "rails_helper"

RSpec.describe ApplicationController, type: :controller do
  controller do
    def application_error
      raise Api::ApplicationError.new(
        code: Api::ErrorCodes::CONFLICT,
        message: "The resource is locked.",
        details: [ { field: "status", message: "cannot be changed" } ]
      )
    end

    def missing_record
      raise ActiveRecord::RecordNotFound, "Event not found"
    end

    def invalid_record
      record = User.new
      record.errors.add(:email, "is invalid")
      raise ActiveRecord::RecordInvalid.new(record)
    end

    def unexpected_error
      raise RuntimeError, "database connection failed"
    end
  end

  before do
    routes.draw do
      get "application_error" => "anonymous#application_error"
      get "missing_record" => "anonymous#missing_record"
      get "invalid_record" => "anonymous#invalid_record"
      get "unexpected_error" => "anonymous#unexpected_error"
    end
  end

  it "renders application errors using their code, message, details, and status" do
    get :application_error

    expect(response).to have_http_status(:conflict)
    expect(response.parsed_body).to eq(
      "code" => "CONFLICT",
      "message" => "The resource is locked.",
      "details" => [ { "field" => "status", "message" => "cannot be changed" } ]
    )
  end

  it "maps missing records to a not found response" do
    get :missing_record

    expect(response).to have_http_status(:not_found)
    expect(response.parsed_body).to include(
      "code" => "NOT_FOUND",
      "details" => []
    )
  end

  it "maps validation errors to an unprocessable entity response" do
    get :invalid_record

    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.parsed_body).to eq(
      "code" => "VALIDATION_FAILED",
      "message" => "The request is invalid.",
      "details" => [ { "field" => "email", "message" => "is invalid" } ]
    )
  end

  it "does not expose unexpected exception details" do
    expect(Rails.logger).to receive(:error).twice

    get :unexpected_error

    expect(response).to have_http_status(:internal_server_error)
    expect(response.parsed_body).to eq(
      "code" => "INTERNAL_SERVER_ERROR",
      "message" => "An unexpected error occurred.",
      "details" => []
    )
  end
end
