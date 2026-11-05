class ApplicationController < ActionController::API
  include ErrorRendering
  include Authenticatable
  include Authorizable
end
