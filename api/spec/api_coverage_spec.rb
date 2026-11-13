# frozen_string_literal: true

require "rails_helper"

RSpec.describe "API coverage" do
  IGNORED_ROUTES = [
    "POST /api/v1/dev/confirmation-token"
  ].freeze

  def app_routes
    Rails.application.routes.routes.flat_map do |route|
      controller = route.defaults[:controller]
      next [] unless controller && Rails.root.join("app/controllers/#{controller}_controller.rb").exist?

      path = route.path.spec.to_s.sub("(.:format)", "").gsub(/:(\w+)/, '{\1}')
      route.verb.to_s.split("|").reject { |v| v == "PATCH" }.map { |verb| "#{verb} #{path}" }
    end.uniq
  end

  def documented_routes
    swagger = YAML.load_file(Rails.root.join("swagger/v1/swagger.yaml"))
    swagger["paths"].flat_map do |path, operations|
      operations.keys.map { |verb| "#{verb.upcase} #{path}" }
    end
  end

  it "has a test for every application route" do
    missing = app_routes - documented_routes - IGNORED_ROUTES

    expect(missing).to be_empty, "Routes without rswag specs:\n#{missing.sort.join("\n")}"
  end
end
