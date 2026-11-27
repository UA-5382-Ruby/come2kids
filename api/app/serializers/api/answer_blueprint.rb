# frozen_string_literal: true

module Api
  class AnswerBlueprint < Blueprinter::Base
    identifier :id

    fields :question_id, :text, :created_at, :updated_at

    association :author, blueprint: Api::UserBlueprint
  end
end
