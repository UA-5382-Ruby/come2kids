# frozen_string_literal: true

module Api
  class QuestionBlueprint < Blueprinter::Base
    identifier :id

    fields :target_type, :target_id, :text, :is_hidden, :created_at, :updated_at

    association :author, blueprint: Api::UserBlueprint
    association :answers, blueprint: Api::AnswerBlueprint
  end
end
