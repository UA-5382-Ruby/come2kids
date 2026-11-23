# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Health check', type: :request do
  path '/up' do
    get 'Check that the application boots' do
      tags 'Health'
      description 'Returns 200 when the app boots without exceptions, otherwise 500. Used by load balancers.'

      response '200', 'application is up' do
        run_test!
      end
    end
  end
end
