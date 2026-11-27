# frozen_string_literal: true

# Subscription emails and event reminders (Technical Requirements 3.9, 3.12, 3.13). Each method takes an
# email_outboxes row written by Subscriptions::Enqueue and is called by Emails::ProcessOutboxJob.
#
# Before rendering, every method checks again that the email still makes sense: the recipient is not
# blocked or deleted (FR-SUB-5), still follows the target or holds a ticket, and the event is still in the
# expected state. When a check fails the method does not call `mail`, so nothing is sent.
# Emails are rendered in the recipient's preferred language (FR-SUB-4).
class SubscriptionMailer < ApplicationMailer
  def new_event(outbox)
    with_recipient(outbox) do |payload|
      event = Event.publicly_visible.find_by(id: payload['event_id'])
      subscription = live_subscription(payload)
      next unless event && subscription

      compose('new_event', { title: event.title, organization: event.organization.name },
              details: event_details(event), links: [ event_link(event) ], subscription: subscription)
    end
  end

  def organization_updated(outbox)
    with_recipient(outbox) do |payload|
      organization = Organization.publicly_visible.find_by(id: payload['organization_id'])
      subscription = live_subscription(payload)
      next unless organization && subscription

      compose('organization_updated', { name: organization.name },
              details: organization_details(organization), links: [ organization_link(organization) ],
              subscription: subscription)
    end
  end

  def event_changed(outbox)
    with_recipient(outbox) do |payload|
      event = Event.publicly_visible.find_by(id: payload['event_id'])
      next unless event

      event_email('event_changed', event, payload, details: change_lines(event, payload['changes']))
    end
  end

  def event_cancelled(outbox)
    with_recipient(outbox) do |payload|
      event = Event.where.not(cancelled_at: nil).find_by(id: payload['event_id'])
      next unless event

      event_email('event_cancelled', event, payload, details: event_details(event), with_event_link: false)
    end
  end

  # FR-REM-3: title, date and time in the event time zone, location or online link, a link to the event
  # page and, for ticket holders, a link to their tickets. A reminder made for an older start time (the
  # event was rescheduled and its reminder rows cleared) is not sent.
  def event_reminder(outbox)
    with_recipient(outbox) do |payload|
      event = Event.publicly_visible.find_by(id: payload['event_id'])
      next unless event && event.start_at&.utc&.iso8601 == payload['start_at']
      next unless EventReminder.exists?(event_id: event.id, user_id: @recipient.id)

      event_email('event_reminder', event, payload, details: event_details(event))
    end
  end

  private

  def with_recipient(outbox)
    payload = outbox.payload
    @recipient = Subscriptions::Audience.reachable.find_by(id: payload['user_id'])
    return unless @recipient

    I18n.with_locale(@recipient.preferred_locale.presence || I18n.default_locale) { yield payload }
  end

  # Event emails go to subscribers of the event and to holders of its valid tickets.
  def event_email(key, event, payload, details:, with_event_link: true)
    subscription = live_subscription(payload)
    holder = Subscriptions::Audience.holders(event).exists?(user_id: @recipient.id)
    return unless subscription || holder

    links = []
    links << event_link(event) if with_event_link
    links << tickets_link if holder
    compose(key, { title: event.title }, details: details, links: links, subscription: subscription)
  end

  def compose(key, values, details:, links:, subscription:)
    @heading = t("subscription_mailer.#{key}.heading", **values)
    @body = t("subscription_mailer.#{key}.body", **values)
    @details = details
    @links = links
    @unsubscribe_url = subscription && unsubscribe_url(subscription)
    mail(to: @recipient.email, subject: t("subscription_mailer.#{key}.subject", **values),
         template_name: 'notification')
  end

  def live_subscription(payload)
    return if payload['subscription_id'].blank?

    Subscription.find_by(id: payload['subscription_id'], user_id: @recipient.id)
  end

  def event_details(event)
    [
      labelled(:when, event_time(event.start_at, event.time_zone)),
      labelled(event.location_type == 'online' ? :online : :where, location_text(event.attributes))
    ].compact
  end

  def organization_details(organization)
    [
      labelled(:contact_email, organization.contact_email),
      labelled(:phone, organization.phone),
      labelled(:website, organization.website),
      labelled(:where, [ organization.address, organization.city ].compact_blank.join(', '))
    ].compact
  end

  # One line per changed group, e.g. "Date and time: 1 December 10:00 → 2 December 11:00".
  def change_lines(event, changes)
    (changes || {}).flat_map do |group, change|
      case group
      when 'schedule' then [ schedule_change(change) ]
      when 'location' then [ change_line(:location, location_text(change['from']), location_text(change['to'])) ]
      when 'prices' then price_changes(change)
      else []
      end
    end.presence || event_details(event)
  end

  def schedule_change(change)
    from, to = change.values_at('from', 'to')
    change_line(:schedule, event_time(from['start_at'], from['time_zone']), event_time(to['start_at'], to['time_zone']))
  end

  def price_changes(change)
    from = change['from'] || {}
    to = change['to'] || {}
    (from.keys | to.keys).filter_map do |name|
      next if from[name] == to[name]

      t('subscription_mailer.changes.price', name: name, from: price_text(from[name]), to: price_text(to[name]))
    end
  end

  def change_line(kind, from, to)
    t("subscription_mailer.changes.#{kind}", from: from.presence || none, to: to.presence || none)
  end

  def labelled(label, value)
    return if value.blank?

    "#{t("subscription_mailer.labels.#{label}")}: #{value}"
  end

  def event_time(value, time_zone)
    return if value.blank?

    time = value.is_a?(String) ? Time.zone.parse(value) : value
    "#{I18n.l(time.in_time_zone(time_zone.presence || 'Europe/Kyiv'), format: :long)} (#{time_zone})"
  end

  def location_text(location)
    return if location.blank?
    return location['online_url'] if location['location_type'] == 'online'

    [ location['address'], location['city'] ].compact_blank.join(', ')
  end

  # Ticket prices are stored in kopecks.
  def price_text(kopecks)
    return none if kopecks.nil?
    return t('subscription_mailer.changes.free') if kopecks.to_i.zero?

    format('%.2f UAH', kopecks.to_i / 100.0)
  end

  def none
    t('subscription_mailer.changes.none')
  end

  def event_link(event)
    [ t('subscription_mailer.links.event'), frontend_url("/events/#{event.id}") ]
  end

  def tickets_link
    [ t('subscription_mailer.links.tickets'), frontend_url('/tickets') ]
  end

  def organization_link(organization)
    [ t('subscription_mailer.links.organization'), frontend_url("/organizations/#{organization.slug}") ]
  end

  def unsubscribe_url(subscription)
    token = Subscriptions::UnsubscribeToken.generate(subscription)
    frontend_url("/unsubscribe?#{{ token: token }.to_query}")
  end

  def frontend_url(path)
    "#{Rails.configuration.x.frontend_url}#{path}"
  end
end
