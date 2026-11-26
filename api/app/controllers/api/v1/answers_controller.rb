# frozen_string_literal: true

module Api
  module V1
    class AnswersController < ApplicationController
      before_action :authenticate_user!
      skip_after_action :verify_authorized, raise: false

      def create
        question = Question.find(params[:question_id])
        result = Answers::CreateService.call(
          author: current_user,
          question: question,
          text: answer_params[:text]
        )

        render_result result, blueprint: Api::AnswerBlueprint, status: :created
      end

      private

      def answer_params
        params.permit(:text)
      end
    end
  end
end
