# frozen_string_literal: true

module Api
  module V1
    module Moderation
      class QuestionsController < BaseController
        skip_after_action :verify_authorized, raise: false

        def index
          scope = Question.platform.includes(:author, answers: :author)
          questions, pagination = paginate_collection(
            scope,
            sortable: { created_at: :created_at },
            default_sort: :created_at
          )

          render_collection questions, blueprint: Api::QuestionBlueprint, pagination: pagination
        end
      end
    end
  end
end
