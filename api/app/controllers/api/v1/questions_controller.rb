# frozen_string_literal: true

module Api
  module V1
    class QuestionsController < ApplicationController
      before_action :authenticate_user!, except: [ :index ]
      skip_after_action :verify_authorized, raise: false

      def index
        scope = target_questions_scope.visible.includes(:author, answers: :author)
        questions, pagination = paginate_collection(
          scope,
          sortable: { created_at: :created_at },
          default_sort: :created_at
        )

        render_collection questions, blueprint: Api::QuestionBlueprint, pagination: pagination
      end

      def create
        target_type, target_id = resolve_target
        result = Questions::CreateService.call(
          author: current_user,
          target_type: target_type,
          target_id: target_id,
          text: question_params[:text]
        )

        render_result result, blueprint: Api::QuestionBlueprint, status: :created
      end

      def destroy
        question = Question.find(params[:id])
        result = Questions::DestroyService.call(actor: current_user, question: question)
        raise result.failure if result.failure?

        head :no_content
      end

      def hide
        question = Question.find(params[:id])
        result = Questions::HideService.call(actor: current_user, question: question)

        render_result result, blueprint: Api::QuestionBlueprint
      end

      private

      def target_questions_scope
        target_type, target_id = resolve_target
        Question.where(target_type: target_type, target_id: target_id)
      end

      def resolve_target
        if params[:event_id].present?
          [ 'Event', Event.find(params[:event_id]).id ]
        elsif params[:organization_id].present?
          [ 'Organization', Organization.find(params[:organization_id]).id ]
        else
          [ 'Platform', nil ]
        end
      end

      def question_params
        params.permit(:text)
      end
    end
  end
end
