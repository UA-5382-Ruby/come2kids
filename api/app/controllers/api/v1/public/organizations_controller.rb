# frozen_string_literal: true

module Api
  module V1
    module Public
      class OrganizationsController < ApplicationController
        skip_after_action :verify_authorized
        before_action :set_locale

        def index
          organizations = Organization.publicly_visible
                                      .includes(:organization_translations)

          organizations = apply_search(organizations) if params[:search].present?

          organizations = organizations.order(created_at: :desc)
                                       .limit(limit_param)
                                       .offset(offset_param)

          render json: Api::Public::OrganizationBlueprint.render(
            organizations,
            root: :organizations,
            meta: { total: Organization.publicly_visible.count }
          )
        end

        def show
          organization = Organization.publicly_visible.find_by(slug: params[:id])

          if organization
            render json: Api::Public::OrganizationBlueprint.render(
              organization,
              root: :organization
            )
          else
            render json: { code: 'NOT_FOUND', message: I18n.t('errors.not_found', default: 'Not found') },
                   status: :not_found
          end
        end

        private

        def set_locale
          locale = params[:locale] || request.headers['Accept-Language']&.split(',')&.first&.strip
          I18n.locale = %i[uk en].include?(locale&.to_sym) ? locale.to_sym : :uk
        end

        def apply_search(scope)
          search_term = "%#{params[:search].strip}%"
          locale = I18n.locale.to_s

          scope.joins(:organization_translations)
               .where(
                 'organization_translations.locale = ? AND organization_translations.name ILIKE ?',
                 locale, search_term
               )
               .or(
                 scope.joins(:organization_translations)
                      .where(
                        "organization_translations.locale = 'uk' AND organization_translations.name ILIKE ?",
                        search_term
                      )
               )
               .distinct
        end

        def limit_param
          [ (params[:limit] || 20).to_i, 100 ].min
        end

        def offset_param
          (params[:offset] || 0).to_i
        end
      end
    end
  end
end
