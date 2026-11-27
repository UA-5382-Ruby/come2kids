# frozen_string_literal: true

class TicketMailer < ApplicationMailer
  def purchase_confirmation(outbox)
    @order = Order.includes(:user, :event, order_items: :ticket_type, tickets: :event).find(outbox.payload.fetch('order_id'))
    @user = @order.user
    @locale = @user.preferred_locale.presence || 'uk'

    I18n.with_locale(@locale) do
      @event_title = event_title
      @event_when = event_when
      @location = location_text
      @items = items
      @total = formatted_total
      attach_pdfs
      mail(to: @user.email, subject: I18n.t('tickets.mail.purchase.subject'))
    end
  end

  private

  def attach_pdfs
    @order.tickets.each do |ticket|
      pdf = Tickets::RenderPdf.call(ticket)
      raise pdf.failure if pdf.failure?

      attachments["ticket-#{ticket.code}.pdf"] = { mime_type: 'application/pdf', content: pdf.value! }
    end
  end

  def event_title
    translations = @order.event.event_translations
    translation = translations.find { |t| t.locale == @locale.to_s } || translations.find { |t| t.locale == 'uk' }
    translation&.title.to_s
  end

  def event_when
    event = @order.event
    I18n.l(event.start_at.in_time_zone(event.time_zone), format: :long)
  end

  def location_text
    event = @order.event
    return event.online_url.to_s if event.location_type == 'online'

    [ event.address, event.city ].compact_blank.join(', ')
  end

  def items
    @order.order_items.map { |item| [ item.ticket_type.name, item.quantity ] }
  end

  def formatted_total
    currency = @order.currency == '980' ? 'UAH' : @order.currency
    "#{(@order.total_amount / 100.0).round(2)} #{currency}"
  end
end
