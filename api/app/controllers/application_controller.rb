class ApplicationController < ActionController::API
  include ActionController::Cookies
  include ErrorRendering
  include Authenticatable
end
