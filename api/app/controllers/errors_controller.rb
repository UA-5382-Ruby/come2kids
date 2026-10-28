class ErrorsController < ApplicationController
    def not_found
       raise Api::Error.new(:not_found, message: "Route not found")
    end
end