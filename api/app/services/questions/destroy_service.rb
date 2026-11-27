# frozen_string_literal: true

module Questions
  class DestroyService
    include Dry::Monads[:result]

    def self.call(...)
      new(...).call
    end

    def initialize(actor:, question:)
      @actor = actor
      @question = question
    end

    def call
      unless @question.author_id == @actor.id
        return Failure(Api::ApplicationError.new(
                         code: Api::ErrorCodes::FORBIDDEN,
                         message: 'You can only delete your own questions.'
                       ))
      end

      @question.destroy!
      Success(true)
    end
  end
end
