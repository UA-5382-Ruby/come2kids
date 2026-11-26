# frozen_string_literal: true

module Questions
  class HideService
    include Dry::Monads[:result]

    def self.call(...)
      new(...).call
    end

    def initialize(actor:, question:)
      @actor = actor
      @question = question
    end

    def call
      unless authorized?
        return Failure(Api::ApplicationError.new(
                         code: Api::ErrorCodes::FORBIDDEN,
                         message: 'You are not allowed to hide this question.'
                       ))
      end

      @question.update!(is_hidden: true)
      Success(@question)
    end

    private

    def authorized?
      return true if @actor.moderator?

      organization = target_organization
      return false if organization.nil?

      @actor.owner_of?(organization) || @actor.manager_of?(organization)
    end

    def target_organization
      case @question.target_type
      when 'Organization' then @question.target
      when 'Event' then @question.target&.organization
      end
    end
  end
end
