# frozen_string_literal: true

module Tickets
  class RenderQr
    include Dry::Monads[:result]

    FORMATS = %w[png svg].freeze

    def self.call(ticket, format: 'png')
      new(ticket, format:).call
    end

    def initialize(ticket, format:)
      @ticket = ticket
      @format = format.to_s
    end

    def call
      return Failure(:unsupported_format) unless FORMATS.include?(@format)

      qr = RQRCode::QRCode.new(@ticket.qr_token)
      Success(@format == 'png' ? qr.as_png(size: 300, border_modules: 2).to_blob : qr.as_svg(module_size: 6, standalone: true))
    end
  end
end
