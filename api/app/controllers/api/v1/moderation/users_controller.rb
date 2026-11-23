# frozen_string_literal: true

module Api
  module V1
    module Moderation
      # Block and unblock users (US-6.3).
      class UsersController < BaseController
        before_action :load_user

        def block
          authorize [ :moderation, @user ], :block?
          result = ::Moderation::BlockUser.call(user: @user, moderator: current_user, reason: reason_param)
          render_result(result, blueprint: Api::ModerationUserBlueprint)
        end

        def unblock
          authorize [ :moderation, @user ], :block?
          result = ::Moderation::UnblockUser.call(user: @user, moderator: current_user, reason: reason_param)
          render_result(result, blueprint: Api::ModerationUserBlueprint)
        end

        private

        def load_user
          @user = User.find(params[:id])
        end
      end
    end
  end
end
