# frozen_string_literal: true

module Questions
  class CreateService
    include Dry::Monads[:result]

    def self.call(...)
      new(...).call
    end

    def initialize(author:, target_type:, target_id: nil, text:)
      @author = author
      @target_type = target_type
      @target_id = target_id
      @text = text
    end

    def call
      question = Question.new(
        author: @author,
        target_type: @target_type,
        target_id: @target_type == 'Platform' ? nil : @target_id,
        text: @text
      )

      if question.save
        Success(question)
      else
        Failure(Api::ApplicationError.new(
                  code: Api::ErrorCodes::VALIDATION_ERROR,
                  message: 'Validation failed.',
                  details: question.errors.full_messages
                ))
      end
    end
  end
end
