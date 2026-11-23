# frozen_string_literal: true

class ApplicationController < ActionController::API
  include LocaleHandling
  include ErrorHandling
  include Api::QueryParameters
  include Api::ResponseFormat
  include Authenticatable
  include Authorizable

  before_action :set_request_context

  private

  # Request details for audit records written by services and jobs (activity log).
  def set_request_context
    Current.ip = request.remote_ip
    Current.user_agent = request.user_agent
    Current.request_id = request.request_id
  end
end
