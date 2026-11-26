# frozen_string_literal: true

module Answers
  class CreateService
    include Dry::Monads[:result]

    def self.call(...)
      new(...).call
    end

    def initialize(author:, question:, text:)
      @author = author
      @question = question
      @text = text
    end

    def call
      unless authorized?
        return Failure(Api::ApplicationError.new(
                         code: Api::ErrorCodes::FORBIDDEN,
                         message: 'You are not allowed to answer this question.'
                       ))
      end

      answer = @question.answers.build(author: @author, text: @text)

      if answer.save
        QuestionMailer.answer_received(answer).deliver_later
        Success(answer)
      else
        Failure(Api::ApplicationError.new(
                  code: Api::ErrorCodes::VALIDATION_ERROR,
                  message: 'Validation failed.',
                  details: answer.errors.full_messages
                ))
      end
    end

    private

    def authorized?
      return @author.moderator? if @question.platform?

      organization = target_organization
      return false if organization.nil?

      @author.owner_of?(organization) || @author.manager_of?(organization)
    end

    def target_organization
      case @question.target_type
      when 'Organization' then @question.target
      when 'Event' then @question.target&.organization
      end
    end
  end
end
