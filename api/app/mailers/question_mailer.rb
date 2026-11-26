# frozen_string_literal: true

class QuestionMailer < ApplicationMailer
  def answer_received(answer)
    @answer = answer
    @question = answer.question
    @recipient = @question.author

    locale = @recipient.preferred_locale.presence || I18n.default_locale

    I18n.with_locale(locale) do
      mail(
        to: @recipient.email,
        subject: locale.to_s == 'en' ? 'Your question has been answered' : 'На ваше питання відповіли'
      )
    end
  end
end
