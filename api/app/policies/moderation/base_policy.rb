# frozen_string_literal: true

module Moderation
  # Moderation endpoints are for platform moderators only (permission matrix, section 2.1).
  # Controllers authorize with a namespace, e.g. `authorize [:moderation, organization], :decide?`,
  # so these policies never clash with the resource policies used by owners and the public.
  class BasePolicy < ApplicationPolicy
    def index?
      moderator?
    end

    def show?
      moderator?
    end

    def decide?
      moderator?
    end

    class Scope < ApplicationPolicy::Scope
      def resolve
        user&.moderator? ? scope.all : scope.none
      end
    end
  end
end
