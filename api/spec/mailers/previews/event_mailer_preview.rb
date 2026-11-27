# frozen_string_literal: true

class EventMailerPreview < ActionMailer::Preview
  def cancelled
    EventMailer.cancelled(User.first, Event.first, 'Захворів ведучий')
  end

  def changed
    EventMailer.changed(User.first, Event.first, 'Початок перенесено на годину пізніше')
  end

  def published
    EventMailer.published(User.first, Event.first)
  end

  def reminder
    EventMailer.reminder(User.first, Event.first)
  end
end
