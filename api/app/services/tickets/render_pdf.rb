# frozen_string_literal: true

module Tickets
  class RenderPdf
    include Dry::Monads[:result]

    FONT = Rails.root.join('app/assets/fonts/DejaVuSans.ttf').to_s

    def self.call(ticket)
      new(ticket).call
    end

    def initialize(ticket)
      @ticket = ticket
      @locale = ticket.user.preferred_locale.presence || 'uk'
    end

    def call
      Success(build_pdf)
    rescue StandardError => e
      Failure(e)
    end

    private

    def build_pdf
      I18n.with_locale(@locale) do
        pdf = Prawn::Document.new(page_size: 'A4', margin: 40)
        pdf.font FONT
        draw_header(pdf)
        draw_details(pdf)
        draw_qr(pdf)
        draw_footer(pdf)
        pdf.render
      end
    end

    def draw_header(pdf)
      pdf.text I18n.t('tickets.pdf.title'), size: 20
      pdf.move_down 8
      pdf.stroke_horizontal_rule
      pdf.move_down 12
    end

    def draw_details(pdf)
      row(pdf, 'event', event_title)
      row(pdf, 'date', event_time)
      row(pdf, 'location', location_text)
      row(pdf, 'ticket_type', @ticket.ticket_type.name)
      row(pdf, 'holder', "#{@ticket.user.first_name} #{@ticket.user.last_name}")
      pdf.move_down 6
      pdf.text "#{I18n.t('tickets.pdf.code')}: #{@ticket.code}", size: 15
      pdf.move_down 12
    end

    def draw_qr(pdf)
      qr = Tickets::RenderQr.call(@ticket, format: 'png')
      pdf.image StringIO.new(qr.value!), width: 140
      pdf.move_down 4
      pdf.text I18n.t('tickets.pdf.scan_hint'), size: 9
    end

    def draw_footer(pdf)
      pdf.move_down 20
      pdf.text I18n.t('tickets.pdf.footer'), size: 8, color: '666666'
    end

    def row(pdf, key, value)
      pdf.text "#{I18n.t("tickets.pdf.#{key}")}: #{value}", size: 11
      pdf.move_down 4
    end

    def event_title
      translations = @ticket.event.event_translations
      translation = translations.find { |t| t.locale == @locale.to_s } || translations.find { |t| t.locale == 'uk' }
      translation&.title.to_s
    end

    def event_time
      event = @ticket.event
      I18n.l(event.start_at.in_time_zone(event.time_zone), format: :long)
    end

    def location_text
      event = @ticket.event
      return event.online_url.to_s if event.location_type == 'online'

      [ event.address, event.city ].compact_blank.join(', ')
    end
  end
end
