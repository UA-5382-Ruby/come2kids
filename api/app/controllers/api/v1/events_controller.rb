# frozen_string_literal: true

module Api
  module V1
    class EventsController < ApplicationController
      skip_after_action :verify_authorized

      SORTABLE = { 'date' => 'events.start_at', 'created' => 'events.created_at' }.freeze
      FILTERABLE = {
        category_id: 'events.category_id',
        city: 'events.city',
        organization_id: 'events.organization_id'
      }.freeze

      def index
        apply_requested_locale
        records, pagination = paginate_collection(
          Events::CatalogQuery.call(params, locale: requested_locale),
          sortable: SORTABLE,
          filterable: FILTERABLE,
          default_sort: 'date'
        )
        render_collection(records, blueprint: Api::EventBlueprint, pagination: pagination)
      end

      def show
        apply_requested_locale
        event = public_scope.find_by(id: params[:id])
        raise Api::ApplicationError.new(code: Api::ErrorCodes::NOT_FOUND, message: 'Event not found.') if event.nil?

        render json: Api::EventBlueprint.render(event, view: :detail)
      end

      private

      def public_scope
        Events::CatalogQuery.call({}, locale: requested_locale)
      end

      def requested_locale
        params[:locale].presence || I18n.locale
      end

      def apply_requested_locale
        requested = params[:locale].presence
        return if requested.blank?

        locale = requested.to_sym
        I18n.locale = locale if I18n.available_locales.include?(locale)
      end
    end
  end
end
