# frozen_string_literal: true

module Api
  module V1
    module Moderation
      # Moderator-only endpoints (EPIC-6). Every action authorizes with a Moderation:: policy.
      # Services live in the top-level ::Moderation and ::Appeals namespaces; refer to them with a
      # leading :: because this controller namespace is also called Moderation.
      class BaseController < ApplicationController
        before_action :authenticate_user!

        private

        # The `status` filter of a queue: one of `allowed`, or `all`; `default` when it is not given.
        def queue_status(allowed, default:, aliases: {})
          value = params[:status].presence || default
          value = aliases.fetch(value, value)
          return value if value == 'all' || allowed.include?(value)

          invalid_query_parameter(:status, I18n.t('moderation.errors.invalid_status_filter'))
        end

        def filter_by_status(relation, status)
          status == 'all' ? relation : relation.where(status: status)
        end

        def reason_param
          params[:reason]
        end
      end
    end
  end
end
