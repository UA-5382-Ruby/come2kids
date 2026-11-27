# frozen_string_literal: true

class EventMailer < ApplicationMailer
  def cancelled(user, event, reason = nil)
    deliver_notification(user, 'event_cancelled', reason) { event_values(event) }
  end

  def changed(user, event, changes)
    deliver_notification(user, 'event_changed', nil) { event_values(event).merge(changes: changes) }
  end

  def published(user, event)
    deliver_notification(user, 'event_published', nil) { event_values(event) }
  end

  def reminder(user, event)
    deliver_notification(user, 'event_reminder', nil) { event_values(event) }
  end

  private

  def event_values(event)
    {
      title: event.title || "##{event.id}",
      organization: event.organization.name,
      date: event_date(event),
      place: event_place(event)
    }
  end

  def event_date(event)
    return '' if event.start_at.nil?

    I18n.l(event.start_at.in_time_zone(event.time_zone), format: :long)
  end

  def event_place(event)
    return event.online_url.to_s if event.location_type == 'online'

    [ event.address, event.city ].compact_blank.join(', ')
  end

  def deliver_notification(recipient, key, reason)
    I18n.with_locale(recipient.preferred_locale) do
      values = block_given? ? yield : {}
      @recipient = recipient
      @heading = t("event_mailer.#{key}.heading", **values)
      @body = t("event_mailer.#{key}.body", **values)
      @reason = reason.presence
      mail(to: recipient.email, subject: t("event_mailer.#{key}.subject", **values),
           template_name: 'notification')
    end
  end
end
