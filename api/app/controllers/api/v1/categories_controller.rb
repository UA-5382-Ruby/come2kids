# frozen_string_literal: true

module Api
  module V1
    class CategoriesController < ApplicationController
      skip_after_action :verify_authorized

      def index
        apply_requested_locale
        categories = Category.order(:position, :id)
        render json: { data: Api::CategoryBlueprint.render_as_hash(categories) }
      end

      private

      def apply_requested_locale
        requested = params[:locale].presence
        return if requested.blank?

        locale = requested.to_sym
        I18n.locale = locale if I18n.available_locales.include?(locale)
      end
    end
  end
end
