class ApplicationController < ActionController::API
  include ErrorRendering
  include Authenticatable
end
